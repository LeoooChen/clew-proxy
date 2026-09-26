import { computed, ref } from 'vue'
import zhCN from './zh-CN.json'

export type Language = 'system' | 'en' | 'zh-CN'
export function validLanguage(value: unknown): Language {
  return value === 'en' || value === 'zh-CN' ? value : 'system'
}

export function resolveLocale(language: Language, systemLanguage: string): 'en' | 'zh-CN' {
  return language === 'system' ? (/^zh\b/i.test(systemLanguage) ? 'zh-CN' : 'en') : language
}

export const language = ref<Language>('system')
const systemLanguage = ref(navigator.language)
export const locale = computed(() => resolveLocale(language.value, systemLanguage.value))

export function t(key: string, params: Record<string, string | number> = {}): string {
  const message = locale.value === 'zh-CN' ? (zhCN as Record<string, string>)[key] ?? key : key
  return message.replace(/\{(\w+)\}/g, (match, name: string) => String(params[name] ?? match))
}

export function setLanguage(value: unknown) {
  language.value = validLanguage(value)
  try { localStorage.setItem('clew-language', language.value) } catch { /* Storage may be disabled. */ }
  document.documentElement.lang = locale.value
  window.chrome?.webview?.postMessage(`language:${locale.value}`)
}

window.addEventListener('languagechange', () => {
  systemLanguage.value = navigator.language
  setLanguage(language.value)
})

// Load before Monaco is imported: many of its action labels are module constants.
export async function initLocale() {
  // The config file is authoritative; the cache avoids losing the selected
  // language during a transient backend timeout or a frontend-only preview.
  try { setLanguage(localStorage.getItem('clew-language')) } catch { setLanguage('system') }
  try {
    const response = await fetch('/api/config', { signal: AbortSignal.timeout(10000) })
    if (response.ok) setLanguage((await response.json()).ui?.language)
  } catch { /* Keep the cached preference while the backend is unavailable. */ }
  if (locale.value === 'zh-CN') await import('monaco-editor/esm/nls.messages.zh-cn.js')
}
