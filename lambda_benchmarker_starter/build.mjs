import esbuild from 'esbuild';

await esbuild.build({
  bundle: true,
  outdir: '.',
  entryPoints: ['./src/index.ts'],
  outExtension: { // 必須では無いが、ESM形式で出力されることを明示的にするため拡張子を.mjsにしている
    '.js': '.mjs'
  },
  minify: true,
  platform: 'node', // nodejsで実行するため必要
  format: 'esm', // ESMプロジェクトなので、出力フォーマットを'esm'に設定する必要
  banner: { // commonjs用ライブラリをESMプロジェクトでbundleする際に生じることのある問題への対策
    js: 'import { createRequire } from "module"; import url from "url"; const require = createRequire(import.meta.url); const __filename = url.fileURLToPath(import.meta.url); const __dirname = url.fileURLToPath(new URL(".", import.meta.url));',
  },
})