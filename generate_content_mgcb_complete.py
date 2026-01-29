#!/usr/bin/env python3
"""
Gera Content.mgcb completo a partir da estrutura Content/
Suporta: .png, .wav, .ogg, .wem, .json, .bin, .obj, .xml
"""

import os
import sys
from pathlib import Path

def get_importer_processor(filename):
    """Retorna importer e processor baseado na extensão"""
    ext = filename.lower().split('.')[-1]
    
    processors = {
        'png': ('TextureImporter', 'TextureProcessor'),
        'jpg': ('TextureImporter', 'TextureProcessor'),
        'jpeg': ('TextureImporter', 'TextureProcessor'),
        'wav': ('WavImporter', 'SoundEffectProcessor'),
        'ogg': ('OggImporter', 'SoundEffectProcessor'),
        'wem': ('WemImporter', 'SoundEffectProcessor'),
        'json': ('PassThroughImporter', 'PassThroughProcessor'),
        'xml': ('PassThroughImporter', 'PassThroughProcessor'),
        'bin': ('PassThroughImporter', 'PassThroughProcessor'),
        'obj': ('PassThroughImporter', 'PassThroughProcessor'),
        'export': ('PassThroughImporter', 'PassThroughProcessor'),
        'data': ('PassThroughImporter', 'PassThroughProcessor'),
        'meta': ('PassThroughImporter', 'PassThroughProcessor'),
    }
    
    return processors.get(ext, ('PassThroughImporter', 'PassThroughProcessor'))

def generate_mgcb(content_dir='Content', output_file='src/Celeste.Android/Content/Content.mgcb'):
    """Gera arquivo MGCB completo"""
    
    if not os.path.exists(content_dir):
        print(f"Erro: Diretório {content_dir} não encontrado")
        sys.exit(1)
    
    entries = []
    
    # Escaneia todos os arquivos recursivamente
    for root, dirs, files in os.walk(content_dir):
        # Ignora diretórios não desejados
        dirs[:] = [d for d in dirs if d not in ['.git', '__pycache__', '.vs', 'obj', 'bin']]
        
        for file in sorted(files):
            # Ignora certos tipos
            if file.endswith(('.mgcb', '.csproj', '.sln')):
                continue
            
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, content_dir)
            
            importer, processor = get_importer_processor(file)
            
            # Cria entrada
            entry = f"""#begin {rel_path}
/importer:{importer}
/processor:{processor}
/processorParam:TextureFormat=Compressed
/build:{rel_path}
"""
            entries.append(entry)
    
    # Gera arquivo MGCB
    mgcb_content = """#----------------------------- Global Properties ----------------------------#

/outputDir:bin/$(Platform)
/intermediateDir:obj/$(Platform)
/platform:Android

#-------------------------------- References --------------------------------#

/reference:../Celeste.Core/bin/$(Configuration)/net9.0/Celeste.Core.dll

#---------------------------------- Content ---------------------------------#

"""
    
    # Agrupa por tipo
    textures = [e for e in entries if 'TextureProcessor' in e]
    sounds = [e for e in entries if 'SoundEffectProcessor' in e]
    other = [e for e in entries if 'PassThroughProcessor' in e]
    
    if textures:
        mgcb_content += "\n#-------------------------------- Textures --------------------------------#\n"
        mgcb_content += "".join(textures)
    
    if sounds:
        mgcb_content += "\n#-------------------------------- Sounds ----------------------------------#\n"
        mgcb_content += "".join(sounds)
    
    if other:
        mgcb_content += "\n#-------------------------------- Data -----------------------------------#\n"
        mgcb_content += "".join(other)
    
    mgcb_content += """
#----------------------------------- Fonts -----------------------------------#

/importer:FontDescriptionImporter
/processor:FontDescriptionProcessor
/processorParam:TextureFormat=Compressed

#-------------------------------- Build Flags --------------------------------#

/compress
"""
    
    # Escreve arquivo
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'w') as f:
        f.write(mgcb_content)
    
    print(f"✅ Gerado: {output_file}")
    print(f"   Texturas: {len(textures)}")
    print(f"   Sons: {len(sounds)}")
    print(f"   Dados: {len(other)}")
    print(f"   Total: {len(entries)}")
    print(f"   Tamanho: {os.path.getsize(output_file) / 1024:.1f} KB")

if __name__ == '__main__':
    generate_mgcb()
