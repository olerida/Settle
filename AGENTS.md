Si se hacen modificaciones en la app, se debe mantener la localización correcta en:
- Inglés
- Español
- Catalán
- Francés
- Alemán

No se deben introducir textos hardcodeados nuevos en la UI sin añadir o actualizar sus traducciones correspondientes en `en.lproj`, `es.lproj`, `ca.lproj`, `fr.lproj` y `de.lproj`.

Se debe mantener un registro de release notes actualizado con los cambios relevantes de cada version publicada o preparada para publicar.

Las versiones de la app y las releases de GitHub se deben gestionar con versionado semántico en formato `vX.Y.Z`.

Al hacer cambios funcionales, correcciones relevantes, despliegues o publicaciones:
- se debe evaluar si corresponde subir versión
- se debe actualizar la versión de la app de forma coherente
- se debe mantener `CHANGELOG.md` al día con los cambios de la versión preparada o publicada
- se debe crear o actualizar la release de GitHub alineada con ese mismo tag `vX.Y.Z`
