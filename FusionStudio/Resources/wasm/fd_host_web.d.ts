/* tslint:disable */
/* eslint-disable */

/**
 * 宿主外壳（wasm_bindgen 公开类型）。
 */
export class WebShell {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
}

/**
 * fusionBridge.sendCommand(commandJson) — 供 WKWebView 原生端调用。
 */
export function fusion_bridge_send_command(command_json: string): void;

/**
 * 初始化 Web 宿主。
 *
 * 验证 canvas 元素存在，初始化 panic hook，返回 WebShell 实例。
 * 对应 `op-host-web::mount` 的 `<canvas>` 校验逻辑。
 */
export function mount(canvas_id: string): WebShell;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly __wbg_webshell_free: (a: number, b: number) => void;
    readonly fusion_bridge_send_command: (a: number, b: number) => [number, number];
    readonly mount: (a: number, b: number) => [number, number, number];
    readonly wasm_bindgen__convert__closures_____invoke__he56a4b665f145993: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__hec56b86a89fd6ca5: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h7c44b051d78367e7: (a: number, b: number) => void;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __wbindgen_destroy_closure: (a: number, b: number) => void;
    readonly __externref_table_dealloc: (a: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
