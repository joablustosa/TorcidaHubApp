# Referência: WEB App (TorcidaHub)

Este documento resume o diretório **WEB App** para servir de base nas implementações do app mobile. O WEB App é a aplicação web do TorcidaHub (React + Vite + Supabase) e contém o schema do banco, Edge Functions e fluxos que o mobile deve respeitar.

---

## Estrutura do diretório WEB App

```
WEB App/
├── src/
│   ├── components/       # Componentes React (feed, eventos, álbuns, notificações, admin, etc.)
│   ├── contexts/        # AuthContext
│   ├── hooks/            # Hooks (notificações, dados)
│   ├── integrations/     # Cliente Supabase (client.ts, types.ts)
│   ├── lib/              # Utilitários
│   └── pages/            # Páginas (Dashboard, MinhaTorcida, Perfil, Login, etc.)
├── supabase/
│   ├── config.toml
│   ├── migrations/       # SQL: tabelas, RLS, triggers (ordem por data no nome)
│   └── functions/        # Edge Functions (pagamentos, email, webhooks)
├── ANALISE_PROJETO.md    # Análise de funcionalidades (álbuns, denúncias, etc.)
├── CONFIGURACAO_NOTIFICACOES.md  # Como notificações in-app e email funcionam
├── SETUP.md             # Setup local (Node, .env, migrações)
└── README.md
```

---

## Banco de dados (Supabase)

As definições oficiais estão em **supabase/migrations/** (executar na ordem do nome). O **types.ts** em `src/integrations/supabase/types.ts` reflete o schema (Tables, Insert, Update).

### Tabelas principais (alinhar no mobile)

- **profiles** – usuários (full_name, nickname, avatar_url, email, etc.)
- **fan_clubs** – torcidas/times
- **fan_club_members** – membros (position, status, badge_level, registration_number, points)
- **fan_club_positions** – cargos e permissões
- **posts**, **post_likes**, **post_comments**
- **events**, **event_registrations**
- **notifications** – notificações in-app (ver abaixo)
- **photo_albums**, **album_photos**, **album_photo_likes**, **album_photo_comments**
- **photo_reports** – denúncias de fotos
- **membership_requests**
- Loja: **products**, **orders**, **order_items**, etc.

### Notificações (tabela `notifications`)

Schema usado pela WEB App (e que o mobile deve usar):

| Coluna        | Tipo      | Descrição                          |
|---------------|-----------|------------------------------------|
| id            | uuid      | PK                                 |
| user_id       | uuid      | Destinatário                       |
| fan_club_id   | uuid      | Opcional, torcida relacionada     |
| type          | text      | Tipo (ex.: post_like, post_comment, event, photo_like, payment_confirmed, store_order_confirmed) |
| title         | text      | Título                             |
| message       | text      | Corpo/descrição (opcional)         |
| is_read       | boolean   | Default false                      |
| reference_id  | uuid      | ID do post/evento/foto/etc.        |
| created_at    | timestamptz |                                  |

Tipos de notificação usados na WEB: `new_post`, `post_like`, `post_comment`, `comment_reply`, `comment_like`, `event`, `photo_like`, `photo_comment`, `photo_report`, `membership_request`, `request_approved`, `request_rejected`, `new_member`, `announcement`, `payment_confirmed`, `store_order_confirmed`, `store_sale`.

Notificações são criadas por triggers/backend quando: curtida em post, comentário, like/comentário em foto, pedido na loja, denúncia de foto, etc. A WEB usa Realtime na tabela `notifications` para atualizar o sininho em tempo real.

---

## Edge Functions (supabase/functions)

- **create-pagarme-payment**, **create-woovi-payment**, **create-store-payment**, **create-woovi-store-payment** – pagamentos
- **pagarme-webhook**, **woovi-webhook** – webhooks de pagamento
- **send-email-hook**, **send-email**, **send-member-notification**, **send-confirmation-email** – emails
- **create-membership-payment** – pagamento de mensalidade/assinatura
- **get-woovi-balance**, **list-woovi-subaccounts**, **request-woovi-withdrawal** – Woovi
- **generate-kyc-link**, **validate-cnpj** – KYC/CNPJ
- **fetch-sports-news**, **fetch-standings** – notícias/tabela

O mobile que chama pagamentos deve usar as mesmas funções/contratos (ex.: parâmetros e formato de resposta).

---

## Componentes e fluxos úteis para o mobile

- **notifications/NotificationBell.tsx** – busca notificações (`notifications`), `is_read`, `message`, tipos e rotas; Realtime; marcar como lida.
- **feed/** – CreatePostForm, PostCard, CommentSection (posts, likes, comentários).
- **events/** – CreateEventDialog, EventCard, EventsSection, caravanas, QRScanner.
- **albums/** – AlbumsSection, AlbumGallery, PhotoViewer, CreateAlbumDialog, ReportPhotoDialog; **admin/PhotoReportsManager** – denúncias.
- **membership/** – MembershipSection, MembershipPaymentDialog, MembershipAccessSettings.
- **admin/** – FanClubSettings, MemberList, MembershipPlansManager, ProductsManager, StoreDashboard, OrdersManager, PayoutsManager, PermissionsManager, PositionsManager, etc.
- **store/** – StoreSection, ProductCheckoutDialog.
- **payments/** – PixPaymentDialog.

Ao implementar algo no mobile, conferir o componente ou página equivalente na WEB e o schema em **migrations** ou **types.ts**.

---

## Documentos de configuração

- **CONFIGURACAO_NOTIFICACOES.md** – notificações in-app (RLS, Realtime, política de INSERT), hook de email, troubleshooting.
- **ANALISE_PROJETO.md** – álbuns, denúncias, feed, eventos, loja, pagamentos, gamificação, membros, admin.
- **SETUP.md** – variáveis de ambiente (VITE_SUPABASE_URL, VITE_SUPABASE_PUBLISHABLE_KEY), migrações, bucket `fan-club-assets`.

---

## Regras para o app mobile

1. **Schema** – Usar os mesmos nomes de tabelas e colunas que as migrações e o **types.ts** (ex.: `notifications`: `is_read`, `message`; não inventar `read`, `body`, `read_at` se não existirem no schema).
2. **Notificações** – Ler da tabela `notifications`, filtrar por `user_id`, ordenar por `created_at` desc, usar `type` para ícone/rota; marcar como lida com `update({ is_read: true })`.
3. **Pagamentos** – Chamar as mesmas Edge Functions que a WEB (ou a API que a WEB usa), com os mesmos parâmetros quando aplicável.
4. **RLS** – O Supabase já está configurado na WEB; o mobile usa a mesma anon key e as mesmas políticas (SELECT/INSERT/UPDATE por usuário/torcida).

Última atualização deste resumo: a partir da análise do diretório WEB App e do schema em migrations + types.ts.
