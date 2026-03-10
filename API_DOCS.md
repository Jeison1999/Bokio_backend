# Bokio API Documentation

**Base URL:** `http://localhost:3000/api/v1`  
**Producción:** `https://tu-dominio.com/api/v1`  
**Formato:** JSON  
**Autenticación:** JWT Bearer Token en el header `Authorization: Bearer <token>`

---

## Autenticación

### Roles del sistema
| Rol | Descripción |
|-----|-------------|
| `super_admin` | Administrador de la plataforma Bokio |
| `admin` | Dueño de un negocio |
| `employee` | Empleado de un negocio |
| `client` | Cliente que usa la app |

---

## 1. Auth

### `POST /auth/sign_up`
Registro de nuevo usuario.

**Acceso:** Público

**Body:**
```json
{
  "user": {
    "name": "Juan Pérez",
    "email": "juan@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "phone": "3001234567",
    "role": "client"
  }
}
```
> `role` puede ser: `client`, `admin`. No se puede registrar como `super_admin` o `employee` (los empleados son creados por el admin).

**Respuesta 201:**
```json
{
  "message": "Signed up successfully.",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "data": {
    "id": 1,
    "email": "juan@example.com",
    "name": "Juan Pérez",
    "phone": "3001234567",
    "avatar_url": null,
    "role": "client"
  }
}
```

---

### `POST /auth/sign_in`
Inicio de sesión.

**Acceso:** Público

**Body:**
```json
{
  "user": {
    "email": "juan@example.com",
    "password": "password123"
  }
}
```

**Respuesta 200:**
```json
{
  "message": "Logged in successfully.",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "data": {
    "id": 1,
    "email": "juan@example.com",
    "name": "Juan Pérez",
    "phone": "3001234567",
    "avatar_url": null,
    "role": "admin",
    "created_at": "2026-03-10T21:00:00.000Z"
  }
}
```

> **Importante para Angular:** Guardar el `token` en `localStorage` y el `data` en el estado de la app (NgRx/servicio). Enviar el token en cada request como `Authorization: Bearer <token>`.

---

### `DELETE /auth/sign_out`
Cierre de sesión. Invalida el token JWT.

**Acceso:** Autenticado

**Headers:** `Authorization: Bearer <token>`

**Respuesta 200:**
```json
{ "message": "Logged out successfully." }
```

---

## 2. Negocios

### `GET /businesses`
Lista de negocios.

**Acceso:** Todos (autenticados)  
- **Cliente/Super Admin:** Ve todos los negocios activos con suscripción válida  
- **Admin:** Solo ve sus propios negocios  
- **Employee:** Solo ve el negocio donde trabaja  

**Query params opcionales:**
- `?q=barberia` → Búsqueda por nombre o descripción (case-insensitive)

**Respuesta 200:** Array de negocios
```json
[
  {
    "id": 1,
    "name": "Barbería Los Amigos",
    "description": "La mejor barbería...",
    "slug": "barberia-los-amigos",
    "address": "Calle 123 #45-67, Bogotá",
    "phone": "3001234567",
    "logo_url": null,
    "opening_time": "2000-01-01T08:00:00.000Z",
    "closing_time": "2000-01-01T18:00:00.000Z",
    "break_start_time": "2000-01-01T12:00:00.000Z",
    "break_end_time": "2000-01-01T13:00:00.000Z",
    "active": true,
    "owner": { "id": 2, "name": "Juan Pérez", "email": "juan@example.com" },
    "subscription": { "plan": "basic", "status": "active", "expires_at": "..." }
  }
]
```

---

### `GET /businesses/by_slug/:slug`
Busca un negocio por su slug. Devuelve vista pública con empleados y servicios.  
**Usar este endpoint cuando el cliente selecciona un negocio.**

**Acceso:** Todos (autenticados)

**Ejemplo:** `GET /businesses/by_slug/barberia-los-amigos`

**Respuesta 200:**
```json
{
  "id": 1,
  "name": "Barbería Los Amigos",
  "description": "La mejor barbería...",
  "slug": "barberia-los-amigos",
  "address": "Calle 123 #45-67, Bogotá",
  "phone": "3001234567",
  "logo_url": null,
  "opening_time": "2000-01-01T08:00:00.000Z",
  "closing_time": "2000-01-01T18:00:00.000Z",
  "break_start_time": "2000-01-01T12:00:00.000Z",
  "break_end_time": "2000-01-01T13:00:00.000Z",
  "employees": [
    {
      "id": 1,
      "name": "Carlos Gómez",
      "avatar_url": null,
      "status": "available",
      "services": [
        { "id": 1, "name": "Corte de Cabello", "price": "25000.0", "duration": 30 },
        { "id": 2, "name": "Barba", "price": "15000.0", "duration": 20 }
      ]
    }
  ],
  "services": [
    { "id": 1, "name": "Corte de Cabello", "description": "...", "price": "25000.0", "duration": 30 },
    { "id": 2, "name": "Barba", "description": "...", "price": "15000.0", "duration": 20 }
  ],
  "current_queue_size": 3
}
```

> `current_queue_size`: número de tickets activos (waiting + in_progress). Útil para mostrar "X personas esperando".

---

### `GET /businesses/:id`
Ver detalle de un negocio.

**Acceso:** Todos (autenticados)
- **Cliente:** Recibe la misma respuesta que `by_slug` (vista pública con empleados y servicios)
- **Admin/Super Admin:** Ve datos administrativos completos con suscripción

---

### `POST /businesses`
Crear un nuevo negocio. Se crea automáticamente una suscripción `basic`.

**Acceso:** `admin`, `super_admin`

**Body:**
```json
{
  "business": {
    "name": "Mi Barbería",
    "description": "Descripción del negocio",
    "address": "Calle 10 #20-30",
    "phone": "3001234567",
    "logo_url": "https://...",
    "opening_time": "08:00",
    "closing_time": "18:00",
    "break_start_time": "12:00",
    "break_end_time": "13:00"
  }
}
```

**Respuesta 201:** El negocio creado con su suscripción.

---

### `PATCH /businesses/:id`
Actualizar negocio.

**Acceso:** Dueño del negocio o `super_admin`

**Body:** Mismo formato que create, todos los campos son opcionales.

---

### `DELETE /businesses/:id`
Eliminar negocio.

**Acceso:** Dueño del negocio o `super_admin`

---

## 3. Empleados

### `GET /businesses/:business_id/employees`
Lista empleados del negocio.

**Acceso:** Admin del negocio, empleados del negocio, `super_admin`

**Respuesta 200:** Array de empleados con sus servicios asignados y estado.

```json
[
  {
    "data": {
      "id": "1",
      "type": "employee",
      "attributes": {
        "id": 1,
        "business_id": 1,
        "name": "Carlos Gómez",
        "email": "carlos@barberia.com",
        "phone": "3109876543",
        "avatar_url": null,
        "status": "available",
        "services": [
          { "id": 1, "name": "Corte de Cabello", "price": "25000.0", "duration": 30 }
        ],
        "user": { "id": 3, "email": "empleado@barberia.com", "role": "employee" }
      }
    }
  }
]
```

**Estados del empleado:**
| Estado | Descripción |
|--------|-------------|
| `available` | Disponible para atender |
| `busy` | Atendiendo un cliente |
| `break` | En descanso |
| `offline` | No disponible |

---

### `POST /businesses/:business_id/employees`
Crear empleado. Crea también un usuario `employee` con la contraseña provisional `password123` (cambiar en producción).

**Acceso:** Admin del negocio, `super_admin`

**Body:**
```json
{
  "employee": {
    "name": "Ana García",
    "email": "ana@negocio.com",
    "phone": "3157654321",
    "avatar_url": "https://..."
  }
}
```

**Respuesta 201:** El empleado creado.

---

### `PATCH /businesses/:business_id/employees/:id`
Actualizar empleado (incluye cambiar su estado).

**Acceso:** Admin del negocio, `super_admin`, el propio empleado

**Body para cambiar estado:**
```json
{ "employee": { "status": "break" } }
```

---

### `DELETE /businesses/:business_id/employees/:id`
Eliminar empleado.

**Acceso:** Admin del negocio, `super_admin`

---

### `POST /businesses/:business_id/employees/:id/assign_services`
Asignar servicios a un empleado (reemplaza la lista completa).

**Acceso:** Admin del negocio, `super_admin`

**Body:**
```json
{ "service_ids": [1, 2, 3] }
```

**Respuesta 200:** El empleado con sus servicios actualizados.

---

## 4. Servicios

### `GET /businesses/:business_id/services`
Lista servicios del negocio.

**Acceso:** Todos (autenticados)

**Respuesta 200:** Array de servicios.
```json
[
  {
    "id": 1,
    "name": "Corte de Cabello",
    "description": "Corte moderno con acabados profesionales",
    "price": "25000.0",
    "duration": 30,
    "active": true
  }
]
```

---

### `POST /businesses/:business_id/services`
Crear servicio.

**Acceso:** Admin del negocio, `super_admin`

**Body:**
```json
{
  "service": {
    "name": "Corte de Cabello",
    "description": "Descripción del servicio",
    "price": 25000,
    "duration": 30
  }
}
```

---

### `PATCH /businesses/:business_id/services/:id`
Actualizar servicio.

**Acceso:** Admin del negocio, `super_admin`

---

### `DELETE /businesses/:business_id/services/:id`
Eliminar servicio.

**Acceso:** Admin del negocio, `super_admin`

---

## 5. Tickets

Los tickets son el corazón de Bokio. Representan el turno de un cliente.

### Estados del ticket
```
waiting → in_progress → completed → (mark_as_paid)
waiting → cancelled
waiting → no_show
```

| Estado | Descripción |
|--------|-------------|
| `waiting` | En cola, esperando ser atendido |
| `in_progress` | Siendo atendido por el empleado |
| `completed` | Servicio finalizado |
| `cancelled` | Cancelado |
| `no_show` | El cliente no llegó |

---

### `GET /businesses/:business_id/tickets`
Lista todos los tickets del negocio.

**Acceso:** Admin, empleados del negocio, `super_admin`

**Query params opcionales:**
- `?status=waiting` → Filtra por estado

**Respuesta 200:** Array de tickets en formato JSONAPI. Cada elemento:
```json
{
  "data": {
    "id": "1",
    "type": "ticket",
    "attributes": {
      "id": 1,
      "business_id": 1,
      "ticket_number": "20260310-0001",
      "status": "waiting",
      "queue_position": 1,
      "estimated_time": 30,
      "paid": false,
      "total_amount": "25000.0",
      "started_at": null,
      "completed_at": null,
      "created_at": "2026-03-10T20:00:00.000Z",
      "client": { "id": 4, "name": "María López", "email": "cliente@gmail.com" },
      "employee": { "id": 1, "name": "Carlos Gómez" },
      "services": [
        { "id": 1, "name": "Corte de Cabello", "price": "25000.0", "duration": 30 }
      ]
    }
  }
}
```

---

### `GET /businesses/:business_id/tickets/queue`
Cola activa del negocio (solo tickets `waiting` e `in_progress`), ordenada por posición.

**Acceso:** Todos (autenticados) — usado para mostrar la cola en tiempo real al cliente.

**Respuesta 200:** Array de tickets activos ordenados por `queue_position`.

---

### `GET /businesses/:business_id/tickets/:id`
Ver un ticket específico.

**Acceso:** Todos (autenticados)

---

### `POST /businesses/:business_id/tickets`
Crear un ticket (el cliente saca su turno).

**Acceso:** `client`, `admin`, `super_admin`

**Validaciones:**
- El negocio debe estar abierto (horario configurado)
- La suscripción del negocio debe estar activa

**Body (opcional):**
```json
{
  "ticket": {
    "employee_id": 1
  },
  "service_ids": [1, 2]
}
```
> Si no se manda `employee_id`, el ticket queda sin empleado asignado. Si no hay servicio, `total_amount` será 0.

**Respuesta 201:** El ticket creado con su número y posición en cola.

**Error 422 si el negocio está cerrado:**
```json
{ "error": "Business is closed. Closes at 18:00" }
```
```json
{ "error": "Business is on break until 13:00" }
```

---

### `POST /businesses/:business_id/tickets/:id/start`
El empleado inicia la atención del ticket. Cambia estado a `in_progress`.

**Acceso:** Empleado del negocio, admin, `super_admin`

**Body (opcional):**
```json
{ "employee_id": 1 }
```

---

### `POST /businesses/:business_id/tickets/:id/complete`
El empleado completa la atención. Cambia estado a `completed`.

**Acceso:** Empleado del negocio, admin, `super_admin`

> Al completar, el sistema automáticamente notifica al siguiente cliente en la cola ("Tu turno está próximo").

---

### `POST /businesses/:business_id/tickets/:id/cancel`
Cancelar un ticket.

**Acceso:** Empleado del negocio, admin, `super_admin`

---

### `POST /businesses/:business_id/tickets/:id/no_show`
Marcar como "no se presentó". Solo aplica a tickets en estado `waiting`.

**Acceso:** Empleado del negocio, admin, `super_admin`

**Error 422:**
```json
{ "error": "Only waiting tickets can be marked as no_show" }
```

---

### `PATCH /businesses/:business_id/tickets/:id/mark_as_paid`
Marcar ticket como pagado. Solo aplica a tickets `completed` y no pagados.

**Acceso:** Admin del negocio, `super_admin`

**Error 422:**
```json
{ "error": "Ticket already paid" }
{ "error": "Only completed tickets can be marked as paid" }
```

---

## 6. Estadísticas (Admin del Negocio)

### `GET /businesses/:business_id/stats?period=today`
Resumen estadístico del negocio.

**Acceso:** Admin del negocio, `super_admin`

**Query params:**
- `?period=today` (default)
- `?period=week`
- `?period=month`
- `?period=year`

**Respuesta 200:**
```json
{
  "period": "today",
  "summary": {
    "total_tickets": 15,
    "completed_tickets": 10,
    "paid_tickets": 8,
    "unpaid_tickets": 2,
    "total_revenue": 200000,
    "pending_revenue": 50000,
    "active_clients": 12,
    "average_ticket_value": 20000
  },
  "by_employee": [
    {
      "employee_id": 1,
      "employee_name": "Carlos Gómez",
      "tickets_count": 8,
      "revenue": 160000,
      "average_value": 20000
    }
  ],
  "top_services": [
    {
      "service_id": 1,
      "service_name": "Corte de Cabello",
      "service_price": "25000.0",
      "times_requested": 6,
      "total_revenue": 150000
    }
  ]
}
```

---

### `GET /businesses/:business_id/stats/dashboard`
Dashboard con múltiples períodos para comparativa.

**Acceso:** Admin del negocio, `super_admin`

**Respuesta 200:**
```json
{
  "today": { "total_tickets": 5, "completed_tickets": 3, ... },
  "week": { "total_tickets": 30, ... },
  "month": { "total_tickets": 120, ... },
  "year": { "total_tickets": 1200, ... },
  "daily_chart": [
    { "date": "2026-03-04", "revenue": 150000, "tickets_count": 6 },
    { "date": "2026-03-05", "revenue": 200000, "tickets_count": 8 },
    ...
  ]
}
```

---

### `GET /businesses/:business_id/stats/revenue?period=month`
Ingresos del negocio por período.

**Acceso:** Admin del negocio, `super_admin`

**Respuesta 200:**
```json
{
  "period": "month",
  "total_revenue": 1500000,
  "paid_tickets": 60,
  "average_per_ticket": 25000
}
```

---

### `GET /businesses/:business_id/stats/employees/:employee_id?period=month`
Estadísticas individuales de un empleado.

**Acceso:** Admin del negocio, `super_admin`

---

## 7. Estadísticas (Super Admin)

### `GET /admin/stats/overview?period=today`
Vista general de toda la plataforma.

**Acceso:** Solo `super_admin`

**Respuesta 200:**
```json
{
  "period": "today",
  "platform": {
    "total_tickets": 150,
    "completed_tickets": 100,
    "active_tickets": 30,
    "total_revenue": 3000000,
    "unique_clients": 85,
    "average_ticket_value": 20000
  },
  "businesses": {
    "total": 25,
    "active": 20,
    "suspended": 5,
    "new_this_month": 3
  },
  "subscriptions": {
    "total": 25,
    "active": 20,
    "mrr": 875000
  }
}
```

---

### `GET /admin/stats/businesses`
Lista todos los negocios con sus estadísticas.

**Acceso:** Solo `super_admin`

---

### `GET /admin/stats/revenue?period=month`
Ingresos de la plataforma.

**Acceso:** Solo `super_admin`

---

### `GET /admin/stats/subscriptions`
Métricas de suscripciones.

**Acceso:** Solo `super_admin`

**Respuesta 200:**
```json
{
  "total": 25,
  "active": 20,
  "suspended": 3,
  "expired": 2,
  "by_plan": { "basic": 10, "pro": 8, "premium": 7 },
  "by_status": { "active": 20, "suspended": 3, "expired": 2 },
  "mrr": 875000,
  "expiring_soon": 3
}
```

> **MRR (Monthly Recurring Revenue):** basic×$25.000 + pro×$45.000 + premium×$70.000

---

## 8. Notificaciones

Las notificaciones se generan automáticamente cuando el sistema detecta que el cliente está próximo en la cola.

### Tipos de notificación
| Tipo | Cuándo se genera |
|------|-----------------|
| `one_away` | Hay 1 cliente antes que tú |
| `next_in_queue` | Eres el próximo |
| `ticket_ready` | Tu turno comenzó |
| `ticket_completed` | Tu ticket fue completado |
| `ticket_cancelled` | Tu ticket fue cancelado |

---

### `GET /notifications`
Lista todas mis notificaciones.

**Acceso:** Autenticado (cada usuario ve solo las suyas)

**Respuesta 200:**
```json
[
  {
    "id": 1,
    "message": "Falta 1 cliente antes que tú en Barbería Los Amigos",
    "notification_type": "one_away",
    "read": false,
    "sent_at": "2026-03-10T20:30:00.000Z",
    "ticket_id": 5
  }
]
```

---

### `GET /notifications/unread`
Solo las notificaciones no leídas.

**Acceso:** Autenticado

**Uso en Angular:** Llamar periódicamente (polling) o usar WebSocket para badge de notificaciones.

---

### `PATCH /notifications/:id/mark_as_read`
Marcar una notificación como leída.

**Acceso:** Autenticado (solo las propias)

---

### `POST /notifications/mark_all_as_read`
Marcar todas las notificaciones como leídas.

**Acceso:** Autenticado

---

## 9. WebSockets (ActionCable)

### Conexión
```
ws://localhost:3000/cable?token=<jwt_token>
```

### Canales disponibles

#### `QueueChannel` — Cola en tiempo real
Suscribirse para recibir actualizaciones de la cola de un negocio.

**Suscripción:**
```json
{ "command": "subscribe", "identifier": "{\"channel\":\"QueueChannel\",\"business_id\":1}" }
```

**Eventos recibidos:**
```json
{
  "action": "ticket_created",
  "ticket": { ... },
  "queue_size": 5
}
```
```json
{
  "action": "ticket_updated",
  "ticket": { ... },
  "queue_size": 4
}
```
```json
{
  "action": "ticket_destroyed",
  "ticket_id": 3,
  "queue_size": 3
}
```

#### `NotificationChannel` — Notificaciones en tiempo real
Recibir notificaciones del usuario autenticado.

**Suscripción:**
```json
{ "command": "subscribe", "identifier": "{\"channel\":\"NotificationChannel\"}" }
```

**Eventos recibidos:**
```json
{
  "action": "new_notification",
  "notification": {
    "id": 1,
    "message": "Falta 1 cliente antes que tú",
    "notification_type": "one_away",
    "read": false,
    "ticket_id": 5
  }
}
```

---

## 10. Manejo de Errores

### Códigos de respuesta
| Código | Significado |
|--------|-------------|
| `200` | OK |
| `201` | Creado |
| `204` | Sin contenido (DELETE exitoso) |
| `401` | No autenticado (token inválido o ausente) |
| `403` | Sin permisos |
| `404` | No encontrado |
| `422` | Error de validación |
| `500` | Error del servidor |

### Formato de errores
```json
{ "error": "Mensaje de error" }
```
```json
{ "errors": ["Error 1", "Error 2"] }
```

---

## 11. Flujo Completo (Angular → API)

### Flujo del Cliente

```
1. POST /auth/sign_in → guardar token
2. GET /businesses?q=barberia → buscar negocio
3. GET /businesses/by_slug/barberia-los-amigos → ver detalle, empleados y servicios
4. POST /businesses/1/tickets → crear ticket con employee_id y service_ids
   ← sistema devuelve ticket con número y posición en cola
5. WS: suscribirse a QueueChannel (business_id: 1)
   ← recibir actualizaciones en tiempo real
6. WS: suscribirse a NotificationChannel
   ← recibir "Falta 1 cliente antes que tú"
7. GET /notifications/unread → ver badge de notificaciones
8. PATCH /notifications/1/mark_as_read → marcar como leída
```

### Flujo del Empleado

```
1. POST /auth/sign_in → guardar token
2. GET /businesses/1/tickets/queue → ver cola actual
3. WS: suscribirse a QueueChannel (business_id: 1)
4. POST /businesses/1/tickets/5/start → iniciar atención
5. POST /businesses/1/tickets/5/complete → finalizar atención
   ← sistema notifica automáticamente al siguiente cliente
6. POST /businesses/1/tickets/7/no_show → cliente no llegó
```

### Flujo del Admin

```
1. POST /auth/sign_in → guardar token
2. GET /businesses → ver mis negocios
3. POST /businesses/1/employees → crear empleados
4. POST /businesses/1/services → crear servicios
5. POST /businesses/1/employees/1/assign_services → asignar servicios
6. GET /businesses/1/stats/dashboard → ver estadísticas
7. PATCH /businesses/1/tickets/5/mark_as_paid → marcar pago
```

---

## 12. Headers requeridos

```http
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

---

## 13. Usuarios de prueba (seeds)

| Rol | Email | Contraseña |
|-----|-------|------------|
| super_admin | superadmin@bokio.com | password123 |
| admin | admin@barberia.com | password123 |
| employee | empleado@barberia.com | password123 |
| client | cliente@gmail.com | password123 |
