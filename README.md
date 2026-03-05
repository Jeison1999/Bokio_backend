# Bokio

**Bokio** es una plataforma **SaaS de gestión de servicios y turnos en tiempo real** para negocios que trabajan con clientes por cita o por fila.

El sistema permite a los negocios administrar empleados, servicios y reservas mientras que los clientes pueden agendar y ver su turno en tiempo real.

Bokio está pensado para negocios como:

* Barberías
* Spas
* Clínicas
* Dentistas
* Centros de estética
* Talleres
* Cualquier negocio basado en servicios

---

# Problema que resuelve

Muchos negocios aún gestionan clientes mediante:

* filas físicas
* agendas en papel
* WhatsApp
* llamadas

Esto genera:

* desorden
* clientes esperando mucho tiempo
* pérdida de información
* mala experiencia del cliente

**Bokio digitaliza completamente este proceso.**

---

# Características principales

* Gestión de negocios
* Gestión de empleados
* Gestión de servicios
* Sistema de reservas
* Generación automática de tickets
* Cola de atención en tiempo real
* Estadísticas del negocio
* Sistema de suscripción SaaS

---

# Roles del sistema

## Super Admin

Administrador global de la plataforma.

Funciones:

* Ver todos los negocios registrados
* Ver información de negocios
* Ver empleados
* Ver servicios y precios
* Ver clientes
* Ver estadísticas generales
* Gestionar suscripciones
* Definir precios de planes
* Aplicar descuentos
* Suspender servicios por falta de pago

---

## Administrador del negocio (Dueño)

Es el dueño del negocio que utiliza Bokio.

Funciones:

* Crear empleados
* Gestionar estado de empleados
* Crear servicios
* Definir precio y duración del servicio
* Configurar información del negocio
* Subir imagen del negocio
* Personalizar su página en Bokio
* Ver estadísticas de ventas
* Ver estadísticas por empleado
* Ver clientes
* Marcar tickets como pagados

Estados de empleado:

* Disponible
* No disponible
* Descanso

---

## Empleado

Persona que presta el servicio dentro del negocio.

Funciones:

* Ver clientes
* Ver información del cliente
* Ver turnos
* Gestionar tickets
* Cambiar estado del ticket
* Ver trabajo del día

Estados de ticket que puede gestionar:

* En proceso
* Finalizado

---

## Cliente

Usuario que utiliza la plataforma para agendar servicios.

Funciones:

* Registrarse
* Iniciar sesión
* Buscar negocios
* Ver servicios
* Agendar citas
* Ver turno en tiempo real
* Ver historial de citas

---

# Flujo del sistema

## 1 Registro del negocio

El dueño del negocio se registra en Bokio.

Debe proporcionar:

* nombre del negocio
* descripción
* imagen
* dirección

Luego selecciona y adquiere un plan de suscripción.

---

## 2 Configuración del negocio

El administrador configura su negocio.

Puede:

* crear empleados
* definir estado de empleados
* crear servicios
* definir precio de servicios
* definir duración de servicios
* definir horarios del negocio
* definir descansos

---

## 3 Acceso de empleados

Los empleados creados por el administrador pueden iniciar sesión en el sistema.

Una vez dentro pueden ver:

* turnos
* clientes
* tickets asignados

---

## 4 Cliente accede a Bokio

El cliente puede acceder mediante:

* aplicación móvil
* aplicación web

Luego puede ver negocios disponibles.

---

## 5 Cliente agenda servicio

El cliente:

1. entra al negocio
2. ve los empleados disponibles
3. selecciona empleado
4. selecciona servicios
5. confirma la reserva

Antes de confirmar puede ver:

* turno actual
* turno estimado
* tiempo de espera aproximado

---

## 6 Generación de ticket

Una vez confirmada la reserva el sistema genera un ticket.

Ejemplo:

Ticket #23

El cliente debe presentarlo en el negocio.

---

## 7 Atención del cliente

El empleado ve el ticket en el sistema.

Cuando el cliente llega:

Estado cambia a:

En proceso

Cuando termina el servicio:

Estado cambia a:

Finalizado

El sistema llama automáticamente al siguiente ticket.

Los clientes pueden ver el estado en tiempo real.

---

## 8 Pago

Después del servicio el cliente paga en el negocio.

El administrador o cajero marca el ticket como:

Pagado

---

# Estados del ticket

Los tickets tienen los siguientes estados:

* Pendiente
* En proceso
* Finalizado
* Pagado

---

# Notificaciones

El sistema puede enviar notificaciones al cliente cuando su turno está próximo.

Ejemplo:

"Tu turno está cerca. Falta un cliente antes que tú."

---

# Tecnologías utilizadas

## Backend

Ruby on Rails

* API REST
* JWT para autenticación
* ActionCable o WebSockets para tiempo real

---

## Frontend Web

Angular o React

---

## Aplicación móvil

Flutter

Principales herramientas:

* Bloc
* Equatable
* Dio o http
* Google Fonts

---

## Base de datos

PostgreSQL

---

## Infraestructura

Docker

---

## Control de versiones

GitHub

---

# Entorno de desarrollo

Herramientas utilizadas durante el desarrollo:

* ngrok
* GitHub Pages
* APK para pruebas de la app

---

# Entorno de producción

Opciones previstas para despliegue:

* Render
* VPS
* AWS

---

# Futuras mejoras

* Sistema de pagos en línea
* Notificaciones push
* Calificación de empleados
* Estadísticas avanzadas
* Sistema de marketplace de negocios
* Integración con Google Maps
* Panel de analítica avanzado

---

# Estado del proyecto

Proyecto en fase de diseño y planificación.

Actualmente se está trabajando en:

* arquitectura del sistema
* modelo de datos
* flujo de usuarios

---

# Autor

Proyecto diseñado y desarrollado por:

Jeison Ortiz
