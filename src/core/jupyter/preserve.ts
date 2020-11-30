/*
* preserve.ts
*
* Copyright (C) 2020 by RStudio, PBC
*
*/

import { generate as generateUuid } from "uuid/v4.ts";

import { kTextHtml, kTextMarkdown } from "../mime.ts";
import { isDisplayData } from "./display_data.ts";
import { JupyterNotebook, JupyterOutputDisplayData } from "./jupyter.ts";

export function removeAndPreserveHtml(
  nb: JupyterNotebook,
): Record<string, string> | undefined {
  const htmlPreserve: { [key: string]: string } = {};

  nb.cells.forEach((cell) => {
    if (cell.cell_type === "code") {
      cell.outputs?.forEach((output) => {
        if (isDisplayData(output)) {
          const displayOutput = output as JupyterOutputDisplayData;
          const html = displayOutput.data[kTextHtml];
          const htmlText = Array.isArray(html) ? html.join("") : html as string;
          // we've seen pandoc choke on plotly's script as HTML, so preserve it
          // and prevent it from receiving a caption
          if (html && isPlotlyLibrary(htmlText)) {
            const key = "preserve" + generateUuid().replaceAll("-", "");
            htmlPreserve[key] = htmlText;
            displayOutput.data[kTextMarkdown] = [key];
            displayOutput.noCaption = true;
            delete displayOutput.data[kTextHtml];
          }
        }
      });
    }
  });

  if (Object.keys(htmlPreserve).length > 0) {
    return htmlPreserve;
  } else {
    return undefined;
  }
}

export function restorePreservedHtml(
  html: string,
  preserve?: Record<string, string>,
) {
  if (preserve) {
    Object.keys(preserve).forEach((key) => {
      const keyLoc = html.indexOf(key);
      html = html.slice(0, keyLoc) + preserve[key] +
        html.slice(keyLoc + key.length);
    });
  }
  return html;
}

function isPlotlyLibrary(html: string) {
  return /^\s*<script type="text\/javascript">/.test(html) &&
    /define\('plotly'/.test(html);
}
