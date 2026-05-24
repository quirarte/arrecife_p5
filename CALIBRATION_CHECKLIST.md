# Checklist de calibracion ROI/blob

1. Abrir el sketch y verificar que la camara activa sea la correcta (`P` para preview webcam).
2. Activar modo ROI con `O`.
3. Mover ROI con flechas para cubrir solo el area util (sin bordes de mesa/pared).
4. Redimensionar ROI con las flechas hasta ajustar el encuadre.
5. Ajustar `whiteThr` con `,` y `.`:
   - Si se recortan zonas claras del objeto, subir umbral.
   - Si entra demasiado fondo claro, bajar umbral.
6. Ajustar la luz fija de la matriz con `J` y `K` hasta obtener una imagen estable.
7. Probar una captura (`ESPACIO`) y validar resultado visual del pez generado.
8. Guardar calibracion con `S` (genera/actualiza `roi.json`, incluyendo `matrixLedCount`).
9. Salir de modo ROI con `O`.
10. Registrar fecha/hora y condiciones de luz del montaje para repetibilidad.
