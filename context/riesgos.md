# Riesgos del sistema Bokio

## 1. Errores en el sistema de reservas

**1.1 Doble reserva del mismo empleado**

Dos clientes pueden reservar al mismo empleado en el mismo horario.

**Riesgo**

- conflicto de agenda
- clientes molestos

**Prevención**

- validar disponibilidad antes de crear reserva
- usar transacciones en base de datos

---

**1.2 Duración incorrecta de servicios**

Si un cliente selecciona varios servicios, el sistema puede calcular mal el tiempo total.

Ejemplo:

```
Corte 30 min
Barba 20 min
Total real = 50 min
```

Si el sistema solo toma el primero, se romperá la agenda.

---

**1.3 Cliente reserva fuera del horario del negocio**

Ejemplo:

```
Negocio cierra 8:00 pm
Cliente reserva 8:30 pm
```

Debe validarse horario de apertura y cierre.

---

**1.4 Cliente reserva en horario de descanso del empleado**

Ejemplo:

```
Descanso 12:30 - 1:00
Cliente reserva 12:45
```

Debe bloquearse ese horario.

---

**1.5 Cliente agenda múltiples citas**

Un usuario podría reservar muchos turnos y bloquear la agenda.

Prevención:

- límite de citas activas por cliente

---

**1.6 Cancelaciones de último momento**

Clientes cancelan minutos antes del turno.

Esto genera huecos en la agenda.

---

# 2. Errores en el sistema de turnos

**2.1 Tickets duplicados**

Dos clientes reciben el mismo número de ticket.

Prevención:

- generar número secuencial por negocio o empleado.

---

**2.2 Desorden en la cola**

Un empleado podría cambiar el orden manualmente.

Ejemplo:

```
23
24
25
```

Atiende primero el 25.

Esto genera reclamos.

---

**2.3 Ticket bloqueado**

Empleado inicia un ticket pero no lo finaliza.

La cola se queda congelada.

---

**2.4 Ticket abandonado**

Cliente nunca llega.

Debe existir estado:

```
no_show
```

---

**2.5 Cambio incorrecto de estado**

Ejemplo:

```
pendiente → pagado
```

Sin pasar por proceso.

Debe existir validación de flujo.

---

# 3. Errores del lado del empleado

**3.1 Empleado en descanso recibe clientes**

Si el estado no se respeta.

Estados necesarios:

```
available
busy
break
offline
```

---

**3.2 Empleado elimina tickets**

Podría perderse información.

Debe evitarse o registrarse.

---

**3.3 Empleado cambia servicios**

Si un servicio cambia mientras hay citas activas.

---

**3.4 Empleado atiende cliente equivocado**

Si el sistema no muestra claramente el ticket actual.

---

# 4. Errores del lado del administrador

**4.1 Cambiar precio de servicios con citas activas**

Ejemplo:

```
Corte = 15000
Admin cambia a 20000
```

Pero un ticket ya fue creado.

Debe guardarse precio en el ticket.

---

**4.2 Eliminar servicios usados en reservas**

Debe evitarse eliminar servicios con citas activas.

---

**4.3 Cambiar horarios con citas existentes**

Si cambia horario del negocio podría romper citas.

---

**4.4 Eliminar empleados con citas pendientes**

Debe validarse antes de eliminar.

---

# 5. Errores del lado del cliente

**5.1 Cliente no llega**

Caso muy común.

Debe existir:

```
no_show
```

---

**5.2 Cliente llega tarde**

Debe permitirse:

- saltar turno
- reprogramar

---

**5.3 Cliente crea múltiples cuentas**

Puede duplicar reservas.

---

**5.4 Cliente reserva para otra persona**

Puede generar confusión en el negocio.

---

# 6. Errores de arquitectura SaaS

**6.1 Mezcla de datos entre negocios**

Error grave en multi-tenant.

Ejemplo:

Cliente de barbería A ve datos de barbería B.

Prevención:

todas las consultas deben filtrar:

```
business_id
```

---

**6.2 Escalabilidad**

Si el sistema crece a miles de negocios:

- consultas lentas
- carga alta en base de datos

---

**6.3 Problemas de concurrencia**

Muchos usuarios reservando al mismo tiempo.

---

**6.4 Caídas del sistema**

Si Bokio se cae:

- empleados no ven turnos
- clientes no ven tickets

Debe existir tolerancia a fallos.

---

# 7. Errores de tiempo real

Bokio depende de **actualizaciones en vivo**.

Problemas posibles:

- clientes no ven cambios
- ticket no avanza
- websockets desconectados

---

# 8. Errores de pagos

**8.1 Ticket finalizado sin pagar**

Debe existir estado:

```
paid
```

---

**8.2 Pago duplicado**

El mismo ticket pagado dos veces.

---

**8.3 Cambios de precio después de crear ticket**

Debe guardarse precio en el ticket.

---

# 9. Errores de seguridad

**9.1 Acceso indebido**

Empleado viendo información de otro negocio.

---

**9.2 Cliente viendo datos privados**

Ejemplo:

teléfono de otros clientes.

---

**9.3 API expuesta**

Endpoints sin autenticación.

---

# 10. Errores de suscripción SaaS

**10.1 Negocio sigue usando sistema sin pagar**

Debe existir:

```
status: active
status: suspended
```

---

**10.2 Plan no limita funcionalidades**

Ejemplo:

Plan básico permite empleados ilimitados.

---

**10.3 Error en renovación de suscripción**

Puede suspender negocios activos.

---

# 🧠 Conclusión importante

Los **problemas más críticos para Bokio serán**:

1️⃣ conflictos de reservas

2️⃣ clientes que no llegan

3️⃣ mezcla de datos entre negocios

4️⃣ desorden en tickets

5️⃣ errores en tiempo real

Si esos cinco se controlan bien, el sistema será **muy sólido**.