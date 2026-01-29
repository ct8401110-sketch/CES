Uso Android - Celeste (resumo rápido)

Pré-requisitos:
- .NET SDK com suporte a `net9.0-android`
- Android SDK (com `adb`, `build-tools`, `platforms`)

Build:
```
dotnet build src/Celeste.Core -c Release
dotnet build src/Celeste.Desktop -c Release
dotnet build src/Celeste.Android -c Release -p:AndroidSdkDirectory=/path/to/android-sdk

dotnet publish src/Celeste.Android -c Release -p:AndroidSdkDirectory=/path/to/android-sdk
```

Colocar FMOD nativo (arm64):
1. Baixe o Android FMOD SDK (arm64) do site oficial.
2. Copie os arquivos `.so` para `src/Celeste.Android/jniLibs/arm64-v8a/`.

Como o jogo carrega assets:
- Ao iniciar, a Activity extrai recursivamente `assets/Content/` para o diretório app-specific `Context.GetExternalFilesDir(null)/Content`.
- Em seguida, ajusta internamente o caminho usado pelo engine para apontar para a pasta app-specific. Isso permite que trechos do código que usam `File.OpenRead(Path.Combine(Engine.ContentDirectory, ...))` funcionem corretamente no Android.

Ícone:
- O ícone do app foi gerado em `src/Celeste.Android/Resources/mipmap-*/ic_launcher.png`.
