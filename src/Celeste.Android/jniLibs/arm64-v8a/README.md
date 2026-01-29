Coloque aqui as bibliotecas nativas ARM64 necessárias para FMOD/áudio.

Arquivos esperados (exemplo):
- libfmod.so
- libfmodstudio.so
- libfmodstudioL.so

Instruções:
1. Obtenha o Android FMOD SDK compatível com arm64-v8a do site oficial do FMOD.
2. Copie os arquivos ``.so`` para esta pasta: ``src/Celeste.Android/jniLibs/arm64-v8a/``.
3. Ao compilar, o MSBuild empacotará automaticamente essas bibliotecas no APK.

Nota: Não inclua binários proprietários neste repositório sem a devida licença.
