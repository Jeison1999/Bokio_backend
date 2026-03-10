# Bokio Backend - Estructura del Proyecto

> Guía técnica para desarrolladores. Explica dónde está cada cosa, qué hace cada archivo y cómo se relacionan entre sí.

---

## Stack tecnológico

| Tecnología | Versión | Uso |
|-----------|---------|-----|
| Ruby on Rails | 8.1.2 | Framework principal (modo API) |
| PostgreSQL | latest | Base de datos principal |
| Devise | latest | Autenticación de usuarios |
| devise-jwt | latest | Tokens JWT para la API |
| Pundit | latest | Autorización basada en políticas |
| jsonapi-serializer | latest | Serialización de respuestas JSON |
| ActionCable | (Rails) | WebSockets en tiempo real |
| Solid Cable | (Rails) | Backend de ActionCable con PostgreSQL |
| Solid Queue | (Rails) | Cola de trabajos en background |
| rack-cors | latest | Configuración de CORS para el frontend |

---

## Árbol de directorios completo

```
Bokio_backend/
├── app/
│   ├── channels/           ← WebSockets (ActionCable)
│   ├── controllers/        ← Lógica HTTP de la API
│   ├── models/             ← Modelos ActiveRecord y reglas de negocio
│   ├── policies/           ← Autorización (Pundit)
│   └── serializers/        ← Formato de respuestas JSON
│
├── config/
│   ├── routes.rb           ← Definición de todas las rutas
│   ├── initializers/       ← Configuración al arrancar (CORS, JWT, Devise)
│   └── environments/       ← Configuración por entorno
│
├── db/
│   ├── schema.rb           ← Estado actual de la BD (auto-generado)
│   ├── seeds.rb            ← Datos de prueba
│   └── migrate/            ← Historial de cambios a la BD
│
└── test/                   ← Tests unitarios e integración
```

---

## Modelos (`app/models/`)

Los modelos contienen la lógica de negocio, validaciones, asociaciones y scopes.

### `user.rb`
Representa a cualquier persona que usa el sistema.

**Campos DB:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del usuario |
| `email` | string | Email único (login) |
| `phone` | string | Teléfono |
| `avatar_url` | string | URL de imagen de perfil |
| `role` | integer | Rol (ver enum) |
| `encrypted_password` | string | Manejado por Devise |

**Enum roles:**
```ruby
{ client: 0, employee: 1, admin: 2, super_admin: 3 }
```

**Asociaciones:**
```
User → has_many :businesses (owner_id)     → dueño de negocios
User → has_many :tickets (client_id)       → tickets del cliente
User → has_many :employee_records (user_id) → registros como empleado
User → has_many :notifications             → notificaciones recibidas
```

---

### `business.rb`
Representa un negocio registrado en la plataforma (barbería, spa, etc.).

**Campos DB:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del negocio |
| `slug` | string | URL amigable (auto-generado del nombre) |
| `description` | text | Descripción |
| `address` | string | Dirección |
| `phone` | string | Teléfono (10 dígitos) |
| `logo_url` | string | URL del logo |
| `opening_time` | time | Hora de apertura |
| `closing_time` | time | Hora de cierre |
| `break_start_time` | time | Inicio del descanso |
| `break_end_time` | time | Fin del descanso |
| `active` | boolean | Si está activo (default: true) |
| `owner_id` | bigint | FK → users |

**Métodos importantes:**

| Método | Qué hace |
|--------|----------|
| `open_now?` | Retorna `true` si el negocio está abierto en este momento |
| `open_at?(time)` | Verifica si está abierto en un horario específico |
| `closed_reason(time)` | Devuelve el mensaje de por qué está cerrado ("Cerrado a las 18:00", "En descanso hasta las 13:00", etc.) |
| `subscription_valid?` | Verifica que la suscripción esté activa y no vencida |
| `can_add_employee?` | Verifica si puede agregar más empleados según el plan |
| `employees_limit_reached?` | Retorna `true` si ya se llegó al límite del plan |
| `suspend_for_non_payment!` | Suspende la suscripción y desactiva el negocio |
| `stats_summary(period)` | Devuelve hash con estadísticas del período (tickets, ingresos, etc.) |
| `revenue_by_period(period)` | Total de ingresos del período |
| `stats_by_employee(period)` | Array de estadísticas por empleado, ordenado por ingresos |
| `top_services(period, limit)` | Servicios más solicitados del período |
| `daily_revenue_chart(days)` | Datos para gráfica: últimos N días con ingresos y tickets |
| `tickets_for_period(period)` | Scope de tickets filtrado por período (`:today`, `:week`, `:month`, `:year`) |

**Callback:**
- `before_validation :generate_slug` → genera slug único a partir del nombre al crear

**Scopes:**
```ruby
.active                  # WHERE active = true
.with_valid_subscription # JOIN subscriptions WHERE active AND expires_at > now
```

---

### `subscription.rb`
Suscripción SaaS de un negocio. Se crea automáticamente al crear el negocio con plan `basic`.

**Campos DB:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `business_id` | bigint | FK → businesses |
| `plan` | integer | Plan contratado (enum) |
| `status` | integer | Estado actual (enum) |
| `price` | decimal | Precio mensual en COP |
| `max_employees` | integer | Máximo de empleados permitidos |
| `started_at` | datetime | Fecha de inicio |
| `expires_at` | datetime | Fecha de vencimiento |

**Enum plan:**
```ruby
{ basic: 0, pro: 1, premium: 2 }
# basic   → $25.000/mes → máx 2 empleados
# pro     → $45.000/mes → máx 5 empleados
# premium → $70.000/mes → ilimitados (999)
```

**Enum status:**
```ruby
{ active: 0, suspended: 1, cancelled: 2 }
```

**Métodos:**

| Método | Qué hace |
|--------|----------|
| `expired?` | `expires_at < Time.current` |
| `active_and_valid?` | `active? && !expired?` |

**Callback:**
- `before_validation :set_plan_defaults` → asigna precio y max_employees según el plan al crear

---

### `employee.rb`
Registro de un empleado en un negocio. Puede estar opcionalmente vinculado a un `User`.

**Campos DB:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `business_id` | bigint | FK → businesses |
| `user_id` | bigint | FK → users (opcional) |
| `name` | string | Nombre del empleado |
| `email` | string | Email del empleado |
| `phone` | string | Teléfono |
| `avatar_url` | string | Foto de perfil |
| `status` | integer | Estado actual (enum) |

**Enum status:**
```ruby
{ available: 0, busy: 1, on_break: 2, offline: 3 }
```

**Validación custom:**
- `business_within_employee_limit` → al crear, verifica que el negocio no haya superado el límite del plan

---

### `service.rb`
Servicio ofrecido por un negocio (ej: "Corte de cabello – $25.000 – 30 min").

**Campos DB:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `business_id` | bigint | FK → businesses |
| `name` | string | Nombre del servicio |
| `description` | text | Descripción |
| `price` | decimal | Precio en COP (precision: 10, scale: 2) |
| `duration` | integer | Duración en minutos |
| `active` | boolean | Si está disponible (default: true) |

---

### `ticket.rb`
El turno de un cliente en la cola de un negocio. Es el modelo central del sistema.

**Campos DB:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `business_id` | bigint | FK → businesses |
| `client_id` | bigint | FK → users (el cliente) |
| `employee_id` | bigint | FK → employees (opcional) |
| `ticket_number` | string | Número único del día (ej: `20260310-0001`) |
| `status` | integer | Estado actual (enum) |
| `queue_position` | integer | Posición en la cola |
| `estimated_time` | integer | Tiempo estimado en minutos |
| `started_at` | datetime | Cuándo empezó la atención |
| `completed_at` | datetime | Cuándo terminó la atención |
| `paid` | boolean | Si fue pagado (default: false) |
| `total_amount` | decimal | Total del ticket (suma de servicios) |

**Enum status:**
```ruby
{ waiting: 0, in_progress: 1, completed: 2, cancelled: 3, no_show: 4 }
```

**Flujo de estados:**
```
waiting ──→ in_progress ──→ completed ──→ (mark_as_paid)
waiting ──→ cancelled
waiting ──→ no_show
```

**Callbacks (en orden de ejecución):**
| Callback | Cuándo | Qué hace |
|----------|--------|----------|
| `before_validation :generate_ticket_number` | Al crear | Genera `YYYYMMDD-XXXX` |
| `before_create :set_queue_position` | Al crear | Asigna posición = max_actual + 1 |
| `before_create :calculate_total_amount` | Al crear | Suma precios de servicios |
| `after_create :calculate_estimated_time` | Después de crear | Suma duración de servicios |
| `after_create :broadcast_ticket_created` | Después de crear | Notifica por WebSocket |
| `after_update :broadcast_ticket_updated` | Después de actualizar | Notifica cambios de estado/posición |
| `after_update :check_and_notify_next_clients` | Después de actualizar | Si se completa, notifica al siguiente en cola |
| `after_destroy :broadcast_ticket_destroyed` | Al eliminar | Notifica eliminación |

**Scopes:**
```ruby
.active           # waiting + in_progress
.finished         # completed + cancelled + no_show
.by_business(id)  # por negocio
.ordered_by_queue # ORDER BY queue_position ASC
.paid_tickets     # WHERE paid = true
.unpaid_tickets   # WHERE paid = false
.today            # WHERE created_at >= inicio del día
.this_week        # WHERE created_at >= inicio de la semana
.this_month       # WHERE created_at >= inicio del mes
.this_year        # WHERE created_at >= inicio del año
.date_range(s, e) # WHERE created_at BETWEEN start AND end
```

**Lógica de notificaciones automáticas (`check_and_notify_next_clients`):**
Cuando un ticket pasa a `completed`, el sistema obtiene los primeros 2 tickets en `waiting` y:
1. Al primero: envía `next_in_queue` → "¡Es tu turno!"
2. Al segundo: envía `one_away` → "Falta 1 cliente antes que tú"

---

### `notification.rb`
Notificación enviada a un cliente. Se crea automáticamente por el modelo `Ticket`.

**Campos DB:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `user_id` | bigint | FK → users (receptor) |
| `ticket_id` | bigint | FK → tickets |
| `notification_type` | integer | Tipo de notificación (enum) |
| `message` | text | Texto del mensaje |
| `read` | boolean | Si fue leída (default: false) |
| `sent_at` | datetime | Cuándo se envió por WebSocket |

**Enum notification_type:**
```ruby
{ next_in_queue: 0, one_away: 1, ticket_ready: 2, ticket_completed: 3, ticket_cancelled: 4 }
```

**Métodos:**

| Método | Qué hace |
|--------|----------|
| `mark_as_read!` | `update(read: true)` |
| `broadcast` | Envía la notificación por WebSocket al canal `notifications_user_#{user_id}` |

**Scopes:**
```ruby
.unread           # WHERE read = false
.recent           # ORDER BY created_at DESC
.for_user(id)     # WHERE user_id = id
```

---

### Modelos de tabla intermedia

#### `employee_service.rb`
Une `Employee` ↔ `Service`. Un empleado puede ofrecer múltiples servicios.
- Índice único: `(employee_id, service_id)`

#### `ticket_service.rb`
Une `Ticket` ↔ `Service`. Un ticket puede incluir múltiples servicios.
- Índice único: `(ticket_id, service_id)`

---

## Controladores (`app/controllers/`)

### `application_controller.rb`
Clase base de todos los controladores. Define la lógica compartida.

**Métodos:**

| Método | Qué hace |
|--------|----------|
| `authenticate_user!` | Lee el token JWT del header `Authorization: Bearer <token>`, lo decodifica y asigna `@current_user`. Retorna 401 si el token no es válido. |
| `current_user` | Retorna el usuario autenticado (`@current_user`) |
| `ensure_valid_subscription(business)` | Verifica que el negocio tenga suscripción activa. Retorna 402 si no. El `super_admin` lo omite. |
| `configure_permitted_parameters` | (Devise) Permite `name`, `phone`, `role` en sign_up; `name`, `phone`, `avatar_url` en account_update |
| `user_not_authorized` (private) | Maneja `Pundit::NotAuthorizedError` → responde 403 |

---

### `api/v1/auth/registrations_controller.rb`
Maneja el registro de usuarios (`POST /auth/sign_up`).
- Crea el usuario con los datos enviados
- Devuelve el token JWT y los datos del usuario

### `api/v1/auth/sessions_controller.rb`
Maneja login y logout.
- `create` → `POST /auth/sign_in` → devuelve token
- `destroy` → `DELETE /auth/sign_out` → invalida el token (JWT denylist)

---

### `api/v1/businesses_controller.rb`
CRUD de negocios más la vista pública.

**Acciones:**

| Acción | Ruta | Descripción |
|--------|------|-------------|
| `index` | `GET /businesses` | Lista negocios según el rol. Soporta `?q=` para búsqueda ILIKE por nombre/descripción |
| `by_slug` | `GET /businesses/by_slug/:slug` | Busca por slug. Devuelve `business_public_view` (con empleados y servicios) |
| `show` | `GET /businesses/:id` | Si es cliente → `business_public_view`. Si es admin → vista completa con suscripción |
| `create` | `POST /businesses` | Crea negocio + suscripción `basic` automáticamente |
| `update` | `PATCH /businesses/:id` | Actualiza negocio |
| `destroy` | `DELETE /businesses/:id` | Elimina negocio |

**Método privado `business_public_view(business)`:**
Construye un hash con datos del negocio + empleados con sus servicios activos + todos los servicios activos + `current_queue_size`. Usado para la vista del cliente.

**Params permitidos:**
`name`, `description`, `address`, `phone`, `logo_url`, `opening_time`, `closing_time`, `break_start_time`, `break_end_time`, `active`

---

### `api/v1/employees_controller.rb`
CRUD de empleados + asignación de servicios.

**Acciones:**

| Acción | Ruta | Descripción |
|--------|------|-------------|
| `index` | `GET /businesses/:business_id/employees` | Lista empleados del negocio |
| `show` | `GET /.../employees/:id` | Ver empleado |
| `create` | `POST /.../employees` | Crea empleado y opcionalmente un `User` vinculado con rol `employee` |
| `update` | `PATCH /.../employees/:id` | Actualiza (incluye cambiar `status`) |
| `destroy` | `DELETE /.../employees/:id` | Elimina empleado |
| `assign_services` | `POST /.../employees/:id/assign_services` | Recibe `service_ids: []`, reemplaza servicios asignados |

---

### `api/v1/services_controller.rb`
CRUD estándar de servicios del negocio.

**Acciones:** `index`, `show`, `create`, `update`, `destroy`

**Params permitidos:** `name`, `description`, `price`, `duration`, `active`

---

### `api/v1/tickets_controller.rb`
Gestión completa del ciclo de vida de un ticket.

**Before actions:**
- `authenticate_user!` → todas las acciones
- `set_business` → carga `@business` desde `:business_id` en la URL
- `ensure_valid_subscription(@business)` → solo en `create`, `update`, `start`, `complete`
- `set_ticket` → carga `@ticket` para acciones individuales

**Acciones:**

| Acción | Ruta | Descripción |
|--------|------|-------------|
| `index` | `GET /.../tickets` | Lista tickets. Acepta `?status=waiting` |
| `show` | `GET /.../tickets/:id` | Ver ticket |
| `queue` | `GET /.../tickets/queue` | Cola activa (waiting + in_progress), ordenada |
| `create` | `POST /.../tickets` | **Primero valida horario** con `@business.open_now?`. Si cerrado → 422. Crea ticket y asigna `service_ids` si se envían |
| `update` | `PATCH /.../tickets/:id` | Actualizar |
| `destroy` | `DELETE /.../tickets/:id` | Eliminar |
| `start` | `POST /.../tickets/:id/start` | `waiting → in_progress`. Asigna `started_at` y `employee_id` |
| `complete` | `POST /.../tickets/:id/complete` | `in_progress → completed`. Asigna `completed_at`. Dispara notificaciones automáticas al siguiente en cola |
| `cancel` | `POST /.../tickets/:id/cancel` | Cualquier estado → `cancelled` |
| `no_show` | `POST /.../tickets/:id/no_show` | Solo `waiting → no_show`. Si no es `waiting` → 422 |
| `mark_as_paid` | `PATCH /.../tickets/:id/mark_as_paid` | Solo `completed` y no pagado → `paid: true`. Si ya pagado o no completed → 422 |

---

### `api/v1/stats_controller.rb`
Estadísticas a nivel de negocio. Solo admin del negocio o super_admin.

**Acciones:**

| Acción | Ruta | Params |
|--------|------|--------|
| `index` | `GET /businesses/:id/stats` | `?period=today\|week\|month\|year` |
| `dashboard` | `GET /businesses/:id/stats/dashboard` | — |
| `revenue` | `GET /businesses/:id/stats/revenue` | `?period=` |
| `employee_stats` | `GET /businesses/:id/stats/employees/:employee_id` | `?period=` |

Delega toda la lógica a los métodos del modelo `Business` (`stats_summary`, `daily_revenue_chart`, etc.).

---

### `api/v1/admin/stats_controller.rb`
Estadísticas globales de la plataforma. **Solo `super_admin`.**

**Acciones:**

| Acción | Ruta | Descripción |
|--------|------|-------------|
| `overview` | `GET /admin/stats/overview` | Totales de tickets, negocios, suscripciones y MRR |
| `businesses` | `GET /admin/stats/businesses` | Todos los negocios con sus estadísticas |
| `revenue` | `GET /admin/stats/revenue` | Ingresos totales de la plataforma |
| `subscriptions` | `GET /admin/stats/subscriptions` | MRR, distribución por plan, vencimientos próximos |

---

### `api/v1/notifications_controller.rb`
Gestión de notificaciones del usuario autenticado.

**Acciones:**

| Acción | Ruta | Descripción |
|--------|------|-------------|
| `index` | `GET /notifications` | Todas las notificaciones propias |
| `unread` | `GET /notifications/unread` | Solo las no leídas |
| `mark_as_read` | `PATCH /notifications/:id/mark_as_read` | Marca una como leída |
| `mark_all_as_read` | `POST /notifications/mark_all_as_read` | Marca todas como leídas |

---

## Políticas de Autorización (`app/policies/`)

Usa **Pundit**. Cada modelo tiene su policy que define quién puede hacer qué.

### Cómo funciona Pundit
```ruby
# En el controlador:
authorize @business          # llama BusinessPolicy#update?
authorize @ticket, :start?   # llama TicketPolicy#start?
policy_scope(Business)       # llama BusinessPolicy::Scope#resolve
```

### `business_policy.rb`

| Método | Acceso |
|--------|--------|
| `index?` | Todos |
| `show?` | Todos |
| `create?` | `admin`, `super_admin` |
| `update?` | Dueño del negocio o `super_admin` |
| `destroy?` | Dueño del negocio o `super_admin` |
| **Scope** | `super_admin` → todos; `admin` → sus negocios; `employee` → donde trabaja; `client` → activos |

### `ticket_policy.rb`

| Método | Acceso |
|--------|--------|
| `create?` | `client`, `admin`, `super_admin` |
| `start?` / `complete?` / `cancel?` / `no_show?` | `super_admin`, dueño del negocio, empleado del negocio |
| `update?` / `destroy?` | `super_admin`, dueño del negocio |
| **Scope** | `super_admin` → todos; `admin` → sus negocios; `employee` → su negocio; `client` → solo los suyos |

### `employee_policy.rb`

| Método | Acceso |
|--------|--------|
| `index?` | `super_admin`, dueño del negocio, empleado del negocio |
| `show?` | Todos (para que clientes puedan ver empleados disponibles) |
| `create?` / `update?` / `destroy?` / `assign_services?` | `super_admin`, dueño del negocio |

### `service_policy.rb`

Similar a EmployeePolicy. `index?` y `show?` → todos. Modificaciones → solo admin del negocio o `super_admin`.

---

## Serializers (`app/serializers/`)

Usan **jsonapi-serializer**. Definen qué campos se incluyen en la respuesta JSON y en qué formato.

### `ticket_serializer.rb`
Campos: `id`, `business_id`, `ticket_number`, `status`, `queue_position`, `estimated_time`, `started_at`, `completed_at`, `created_at`, `updated_at`

Atributos calculados:
- `client` → `{ id, name, email, phone }`
- `employee` → `{ id, name, email, phone, status }` (nil si no asignado)
- `services` → array `[{ id, name, description, price, duration }]`
- `total_price` → suma de precios de servicios (string)

### `business_serializer.rb`
Campos: todos los atributos del negocio.
Relaciones: `belongs_to :owner` (UserSerializer), `has_one :subscription`

### `employee_serializer.rb`
Campos: `id`, `business_id`, `name`, `email`, `phone`, `avatar_url`, `status`, `created_at`, `updated_at`

Atributos calculados:
- `user` → datos del usuario vinculado (rol, email, etc.)
- `services` → servicios asignados al empleado

### Otros serializers
- `user_serializer.rb` → `id`, `name`, `email`, `phone`, `avatar_url`, `role`
- `subscription_serializer.rb` → todos los campos de suscripción
- `service_serializer.rb` → todos los campos de servicio

---

## WebSockets (`app/channels/`)

### `application_cable/connection.rb`
Punto de entrada de ActionCable. Actualmente vacío (la autenticación del usuario se hace a nivel de canal con el token JWT en la URL: `ws://localhost:3000/cable?token=<jwt>`).

### `queue_channel.rb`
Canal para actualizaciones de la cola de un negocio en tiempo real.

**Flujo:**
1. Cliente se suscribe enviando `{ business_id: 1 }`
2. Se hace `stream_from "queue_business_#{business_id}"`
3. Cuando un ticket cambia (create/update/destroy), el modelo `Ticket` transmite al canal

**Mensajes recibidos:**
```json
{ "action": "ticket_created", "ticket": {...}, "queue": [...] }
{ "action": "ticket_updated", "ticket": {...}, "queue": [...] }
{ "action": "ticket_destroyed", "ticket": {...}, "queue": [...] }
```

**Quién broadcast:** El modelo `Ticket` en sus callbacks `after_create`, `after_update`, `after_destroy` vía `ActionCable.server.broadcast("queue_business_#{business_id}", ...)`.

### `notification_channel.rb`
Canal de notificaciones personales del usuario.

**Flujo:**
1. Usuario se suscribe (sin params)
2. Se hace `stream_from "notifications_user_#{current_user.id}"`
3. Cuando `Notification#broadcast` es llamado, envía al canal del usuario

**Método `mark_as_read(data)`:** El cliente puede enviar `{ notification_id: 1 }` por WebSocket para marcar como leída sin necesidad de HTTP.

---

## Rutas (`config/routes.rb`)

```
POST   /api/v1/auth/sign_up
POST   /api/v1/auth/sign_in
DELETE /api/v1/auth/sign_out

GET/POST         /api/v1/businesses
GET              /api/v1/businesses/by_slug/:slug
GET/PATCH/DELETE /api/v1/businesses/:id

GET /api/v1/businesses/:business_id/stats
GET /api/v1/businesses/:business_id/stats/dashboard
GET /api/v1/businesses/:business_id/stats/revenue
GET /api/v1/businesses/:business_id/stats/employees/:employee_id

GET/POST         /api/v1/businesses/:business_id/employees
POST             /api/v1/businesses/:business_id/employees/:id/assign_services
GET/PATCH/DELETE /api/v1/businesses/:business_id/employees/:id

GET/POST         /api/v1/businesses/:business_id/services
GET/PATCH/DELETE /api/v1/businesses/:business_id/services/:id

GET    /api/v1/businesses/:business_id/tickets/queue
GET/POST         /api/v1/businesses/:business_id/tickets
GET/PATCH/DELETE /api/v1/businesses/:business_id/tickets/:id
POST   /api/v1/businesses/:business_id/tickets/:id/start
POST   /api/v1/businesses/:business_id/tickets/:id/complete
POST   /api/v1/businesses/:business_id/tickets/:id/cancel
POST   /api/v1/businesses/:business_id/tickets/:id/no_show
PATCH  /api/v1/businesses/:business_id/tickets/:id/mark_as_paid

GET /api/v1/admin/stats/overview
GET /api/v1/admin/stats/businesses
GET /api/v1/admin/stats/revenue
GET /api/v1/admin/stats/subscriptions

GET  /api/v1/notifications
GET  /api/v1/notifications/unread
PATCH /api/v1/notifications/:id/mark_as_read
POST /api/v1/notifications/mark_all_as_read

GET  /up             (health check)
     /cable          (WebSocket ActionCable)
```

---

## Base de datos (`db/`)

### `schema.rb`
Estado actual de todas las tablas. **No editar a mano.** Se actualiza con `rails db:migrate`.

### Tablas y relaciones

```
users
  └─has_many→ businesses (owner_id)
  └─has_many→ tickets (client_id)
  └─has_many→ employee_records/employees (user_id)
  └─has_many→ notifications

businesses
  ├─belongs_to→ users (owner_id)
  ├─has_one→ subscriptions
  ├─has_many→ employees
  ├─has_many→ services
  └─has_many→ tickets

subscriptions
  └─belongs_to→ businesses

employees
  ├─belongs_to→ businesses
  ├─belongs_to→ users (opcional)
  ├─has_many→ employee_services
  └─has_many→ services (through: employee_services)

services
  ├─belongs_to→ businesses
  ├─has_many→ employee_services
  └─has_many→ employees (through: employee_services)

employee_services  ← tabla intermedia employee↔service
  ├─belongs_to→ employees
  └─belongs_to→ services

tickets
  ├─belongs_to→ businesses
  ├─belongs_to→ users (client_id)
  ├─belongs_to→ employees (opcional)
  ├─has_many→ ticket_services
  ├─has_many→ services (through: ticket_services)
  └─has_many→ notifications

ticket_services  ← tabla intermedia ticket↔service
  ├─belongs_to→ tickets
  └─belongs_to→ services

notifications
  ├─belongs_to→ users
  └─belongs_to→ tickets

jwt_denylists  ← tokens invalidados (sign_out)
```

### `migrate/`
Historial de migraciones en orden cronológico:

| Archivo | Qué crea/modifica |
|---------|-------------------|
| `20260310164550_devise_create_users.rb` | Tabla `users` con campos Devise |
| `20260310164733_create_jwt_denylists.rb` | Tabla `jwt_denylists` para logout |
| `20260310171313_create_businesses.rb` | Tabla `businesses` |
| `20260310171323_create_subscriptions.rb` | Tabla `subscriptions` |
| `20260310172939_create_employees.rb` | Tabla `employees` |
| `20260310173106_create_services.rb` | Tabla `services` |
| `20260310173117_create_employee_services.rb` | Tabla intermedia `employee_services` |
| `20260310185018_create_tickets.rb` | Tabla `tickets` |
| `20260310185101_create_ticket_services.rb` | Tabla intermedia `ticket_services` |
| `20260310202003_create_notifications.rb` | Tabla `notifications` |
| `20260310202643_change_notification_type_to_integer.rb` | Cambia `notification_type` a integer (para enum) |
| `20260310204622_add_payment_fields_to_tickets.rb` | Agrega `paid` y `total_amount` a tickets |

### `seeds.rb`
Datos de prueba listos para desarrollo. Ejecutar con `rails db:seed` o `rails db:reset`.

Crea:
- 5 usuarios (super_admin, admin, 2 clients, employee)
- 2 negocios (Barbería Los Amigos + Spa Relax)
- 2 suscripciones (basic + pro)
- 2 empleados con servicios asignados
- 5 servicios distribuidos entre los negocios
- 4 tickets en varios estados

**Credenciales de prueba (contraseña: `password123`):**
| Email | Rol |
|-------|-----|
| superadmin@bokio.com | super_admin |
| admin@barberia.com | admin |
| empleado@barberia.com | employee |
| cliente@gmail.com | client |

---

## Configuración (`config/`)

### `routes.rb`
Define todas las rutas. Ver sección **Rutas** arriba.

### `initializers/cors.rb`
Configura `rack-cors`. En desarrollo acepta **todos los orígenes** (`origins '*'`).  
**⚠️ Cambiar en producción** a los dominios del frontend Angular específicos.

```ruby
# Cambiar esto en producción:
origins '*'
# Por esto:
origins 'https://tu-frontend.com'
```

### `initializers/devise.rb`
Configuración de Devise + devise-jwt. Define:
- La clave secreta JWT (`DEVISE_JWT_SECRET_KEY`)
- Qué requests invalidan el token (logout)
- Dispatch routes para generar tokens

### `database.yml`
Configuración de PostgreSQL por entorno. Usa variables de entorno para credenciales.

### `cable.yml`
Configuración del backend de ActionCable. En producción usa `solid_cable` (PostgreSQL). En desarrollo/test usa `async`.

### `environments/development.rb`
- Caché deshabilitado
- Logs detallados
- CORS permisivo

### `environments/test.rb`
- Base de datos de pruebas separada
- ActionCable en modo `async`

### `environments/production.rb`
- HTTPS obligatorio
- Logs comprimidos
- Assets precompilados

---

## Tests (`test/`)

### `test_helper.rb`
Configuración base de Minitest. Incluye helpers para autenticación JWT en tests.

### `models/`
Tests unitarios de modelos:
- `user_test.rb` → validaciones de User
- `business_test.rb` → validaciones, `open_now?`, `stats_summary`
- `employee_test.rb` → límites del plan
- `service_test.rb` → validaciones
- `subscription_test.rb` → `active_and_valid?`, `expired?`
- `ticket_test.rb` → ciclo de vida, `generate_ticket_number`, notificaciones
- `notification_test.rb` → `mark_as_read!`, `broadcast`

### `channels/`
- `queue_channel_test.rb` → suscripción y mensajes por WebSocket
- `notification_channel_test.rb` → suscripción y `mark_as_read`

### `fixtures/`
Datos YAML de prueba para cada modelo. Se cargan automáticamente en los tests.

---

## Comandos útiles

```bash
# Iniciar servidor
rails s

# Resetear BD y cargar seeds
rails db:reset

# Solo ejecutar seeds
rails db:seed

# Crear y ejecutar migración nueva
rails generate migration NombreDeLaMigracion campo:tipo
rails db:migrate

# Ejecutar todos los tests
rails test

# Ejecutar tests de un archivo específico
rails test test/models/ticket_test.rb

# Ejecutar un test específico por nombre
rails test test/models/ticket_test.rb -n "test_nombre_del_test"

# Ver todas las rutas
rails routes | grep api/v1

# Consola interactiva con la BD
rails console

# Verificar gemas por vulnerabilidades
bundle audit

# Análisis estático de seguridad
brakeman
```

---

## Dónde buscar cuando...

| Necesito... | Buscar en... |
|-------------|-------------|
| Agregar un endpoint nuevo | `config/routes.rb` + `app/controllers/api/v1/` |
| Cambiar qué campos devuelve la API | `app/serializers/` |
| Agregar validaciones a un modelo | `app/models/` |
| Cambiar quién puede acceder a algo | `app/policies/` |
| Agregar una tabla nueva a la BD | `rails generate migration` → `db/migrate/` |
| Ver el estado actual de la BD | `db/schema.rb` |
| Cambiar los datos de prueba | `db/seeds.rb` |
| Configurar CORS para producción | `config/initializers/cors.rb` |
| Agregar un nuevo canal WebSocket | `app/channels/` |
| Entender el flujo de un ticket | `app/models/ticket.rb` + `app/controllers/api/v1/tickets_controller.rb` |
| Entender las notificaciones | `app/models/ticket.rb` (`check_and_notify_next_clients`) + `app/models/notification.rb` |
| Agregar estadísticas del negocio | `app/models/business.rb` + `app/controllers/api/v1/stats_controller.rb` |
| Agregar estadísticas de plataforma | `app/controllers/api/v1/admin/stats_controller.rb` |
