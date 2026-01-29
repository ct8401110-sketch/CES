Logs - Celeste Android

Localização dos logs (Android):
- `Context.GetExternalFilesDir(null)/Logs/` (ex.: `/data/data/<package>/files/Logs/`)

Arquivos gerados:
- `session_YYYY-MM-DD.log` — logs por sessão
- `crash_YYYY-MM-DD_HH-mm-ss.log` — crash logs com stacktrace

Como coletar logs:
1. Conecte o dispositivo via ADB.
2. Use `adb pull /data/data/<package>/files/Logs/ ./Logs` (requer acesso ao dispositivo/root se app não expõe arquivos)
3. Alternativamente, use `adb logcat` para ver logs em tempo real.

Observações:
- O sistema de logs está implementado em `src/Celeste.Android/AndroidServices.cs` (classe `AndroidLogSystem`).
- Em crash, o sistema grava um arquivo `crash_*.log` com stacktrace.
