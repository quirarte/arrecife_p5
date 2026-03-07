# Checklist de calibración ROI/blob

1. Abrir el sketch y verificar que la cámara activa sea la correcta (`P` para preview webcam).
2. Activar modo ROI con `O`.
3. Mover ROI con flechas para cubrir solo el área útil (sin bordes de mesa/pared).
4. Redimensionar ROI con `Shift + flechas` hasta ajustar el encuadre.
5. Ajustar `whiteThr` con `J/U`:
   - Si se recortan zonas claras del objeto, subir umbral.
   - Si entra demasiado fondo claro, bajar umbral.
6. Probar una captura (`ESPACIO`) y validar resultado visual del pez generado.
7. Guardar calibración con `S` (genera/actualiza `roi.json`).
8. Salir de modo ROI con `O`.
9. Registrar fecha/hora y condiciones de luz del montaje para repetibilidad.
