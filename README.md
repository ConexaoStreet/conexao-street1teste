# Executador — Painel Web

Painel PWA para controlar o backend **Executador** no Supabase e acompanhar diagnóstico e reparo de PCs pelo celular.

## Recursos

- Login e cadastro via Supabase Auth
- Pareamento do PC por código ou QR
- Status online/offline
- Diagnóstico rápido e Windows profundo
- Problemas encontrados em tempo real
- Inventário de aplicativos instalados
- Fila de reparos com confirmação
- "Corrigir seguros" limitado a ações de baixo risco
- Atualização em tempo real via Supabase Realtime
- PWA instalável no celular
- Deploy automático no GitHub Pages

## Backend

Supabase: `executador` — projeto `skzyxapvleyktmgshvfp`.

O navegador utiliza somente a **publishable key** pública. Chaves secretas e service-role permanecem exclusivamente no backend.

## Arquitetura

Celular / navegador → Painel PWA → Supabase Auth + agent-api → Executador Agent no Windows → diagnóstico/reparo local.
