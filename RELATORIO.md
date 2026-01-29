Etapa: Integração inicial Android (Content + Ícone + Nativos)
Data/Hora: 2026-01-29 00:00:00
Objetivo: Gerar `Content.mgcb`, embutir assets no projeto Android, adicionar ícone do app em mipmaps, configurar suporte a libs nativas arm64-v8a e ajustar `AndroidManifest.xml` para permissões mínimas.

Mudanças (Criados/Alterados/Removidos):
- Criado: `src/Celeste.Android/Content/Content.mgcb` (gerado automaticamente a partir de `Content/`)
- Criado: mipmaps do ícone em `src/Celeste.Android/Resources/mipmap-*/ic_launcher.png` a partir de imagem fornecida
- Alterado: `src/Celeste.Android/Celeste.Android.csproj` — adicionado `AndroidSupportedAbis` e inclusão de `jniLibs\\arm64-v8a\\*.so` como `AndroidNativeLibrary`
- Criado: `src/Celeste.Android/jniLibs/arm64-v8a/README.md` (instruções para colocar as libs FMOD arm64)
- Alterado: `src/Celeste.Android/AndroidManifest.xml` — removida permissão ampla `QUERY_ALL_PACKAGES` e mantidas somente permissões necessárias

Classes/métodos afetados:
- Nenhuma alteração de código do Core foi necessária nesta etapa (apenas assets e config)

Motivo técnico:
- `Content.mgcb` permite compilar os assets via MonoGame Content Builder para Android e empacotar os XNBs no APK.
- `jniLibs` é padrão Android para incluir libs nativas (.so) como as do FMOD; configuração no csproj garante empacotamento.
- Remoção de `QUERY_ALL_PACKAGES` segue política de permissões mínimas.

Comandos executados:
```
python3 generate_content_mgcb_complete.py
dotnet build src/Celeste.Android -c Release   # (recomendado, ambiente Android SDK necessário)
```

Resultado e correção:
- `src/Celeste.Android/Content/Content.mgcb` gerado com sucesso (1211 entradas)
- Ícones mipmap gerados em `src/Celeste.Android/Resources/`
- Projeto preparado para receber .so nativas em `src/Celeste.Android/jniLibs/arm64-v8a/`

Próximo passo:
1. Fornecer/colocar as bibliotecas nativas FMOD (`.so`) em `src/Celeste.Android/jniLibs/arm64-v8a/`.
2. Executar `dotnet build`/`dotnet publish` em ambiente com Android SDK configurado para validar MGCB e gerar APK.
3. Validar em dispositivo/emulador arm64 que o jogo carrega e que `Content` é lido corretamente.
