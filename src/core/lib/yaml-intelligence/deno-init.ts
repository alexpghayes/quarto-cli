/*
* deno-init.ts
*
* code to initialize yaml intelligence on deno
*
* Copyright (C) 2022 by RStudio, PBC
*
*/

import { resourcePath } from "../../resources.ts";

//@ts-ignore: importing from .js makes type-script unhappy
import { setWasmBinaryFile, TreeSitter } from "../external/tree-sitter-deno.js";
import { setTreeSitter } from "./parsing.ts";

import { init as initNoTreeSitter } from "./deno-init-no-tree-sitter.ts";

export const init = async () => {
  // run standard initialization...
  await initNoTreeSitter(false)();

  // ... and then the tree-sitter specific bits;
  setWasmBinaryFile(
    Deno.readFileSync(resourcePath("editor/tools/yaml/tree-sitter.wasm")),
  );

  //@ts-ignore: importing from .js makes type-script unhappy
  //deno-lint-ignore no-explicit-any
  const treeSitter: any = TreeSitter;
  await treeSitter.init();

  const parser = new treeSitter();
  const language = await treeSitter.Language.load(
    resourcePath("editor/tools/yaml/tree-sitter-yaml.wasm"),
  );
  parser.setLanguage(language);

  setTreeSitter(parser);
};
