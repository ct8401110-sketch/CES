Troubleshooting - Android

Problemas comuns e soluções:

- Build falha por falta de FMOD `.so`:
  - Mensagem: "library not found" ou erros de linking.
  - Solução: Colocar as libs arm64 em `src/Celeste.Android/jniLibs/arm64-v8a/`.

- Content não carregado / assets faltando:
  - Confirme que `src/Celeste.Android/Content/Content.mgcb` existe e foi processado pelo MonoGame Content Builder.
  - Verifique se os arquivos foram extraídos em tempo de execução para `Context.GetExternalFilesDir(null)/Content`.

- Permissões inesperadas/Play Store rejects:
  - Remova permissões amplas (ex.: `QUERY_ALL_PACKAGES`).

- Erros de IO no Android (File.OpenRead falha):
  - Confirme que os assets foram extraídos e que `Monocle.Engine` teve seu `AssemblyDirectory` ajustado via reflexão (feito na `Activity1`).
