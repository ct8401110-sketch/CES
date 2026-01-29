#!/usr/bin/env python3
"""
Gerador automático de Content.mgcb
Escaneia a pasta Content e gera configuração MGCB para compilação de assets
"""

import os
from pathlib import Path

def generate_content_mgcb(content_dir: str, output_file: str) -> bool:
    """
    Gera arquivo Content.mgcb automáticamente a partir dos arquivos em Content/
    
    Args:
        content_dir: Diretório raiz dos assets
        output_file: Arquivo de saída Content.mgcb
    
    Returns:
        True se sucesso
    """
    try:
        mgcb_content = """#----------------------------- Global Properties ----------------------------#

/outputDir:bin/$(Platform)
/intermediateDir:obj/$(Platform)
/platform:Android

#-------------------------------- References --------------------------------#

/reference:../Celeste.Core/bin/$(Configuration)/net8.0/Celeste.Core.dll

#---------------------------------- Content ---------------------------------#

"""
        
        # Mapear tipos de arquivo para processadores MGCB
        processors = {
            '.png': ('TextureProcessor', 'TextureFormat=Color'),
            '.jpg': ('TextureProcessor', 'TextureFormat=Color'),
            '.jpeg': ('TextureProcessor', 'TextureFormat=Color'),
            '.bmp': ('TextureProcessor', 'TextureFormat=Color'),
            '.xnb': ('PassThroughProcessor', ''),
            '.bin': ('PassThroughProcessor', ''),
            '.xml': ('XmlImporter', ''),
            '.json': ('JsonImporter', ''),
            '.txt': ('PassThroughProcessor', ''),
            '.fnt': ('FontDescriptionProcessor', 'TextureFormat=Compressed'),
        }
        
        # Tipos de pasta especiais
        special_dirs = {
            'Audio': '#/copy:Audio',
            'Maps': '#/copy:Maps',
            'Overworld': '#/copy:Overworld',
        }
        
        # Escanear diretório Content
        if not os.path.isdir(content_dir):
            print(f"Erro: Diretório não encontrado: {content_dir}")
            return False
        
        # Listar pastas de conteúdo
        for item in sorted(os.listdir(content_dir)):
            item_path = os.path.join(content_dir, item)
            
            if os.path.isdir(item_path):
                if item in special_dirs:
                    mgcb_content += f"\n{special_dirs[item]}\n"
                else:
                    mgcb_content += f"\n#/copy:{item}\n"
        
        # Adicionar configurações globais de compilação
        mgcb_content += """

#----------------------------------- Fonts -----------------------------------#

/importer:FontDescriptionImporter
/processor:FontDescriptionProcessor
/processorParam:TextureFormat=Compressed

#-------------------------------- Build Flags --------------------------------#

/compress

"""
        
        # Escrever arquivo
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, 'w') as f:
            f.write(mgcb_content)
        
        print(f"✅ Content.mgcb gerado com sucesso: {output_file}")
        print(f"   Tamanho: {len(mgcb_content)} bytes")
        return True
        
    except Exception as e:
        print(f"❌ Erro ao gerar Content.mgcb: {e}")
        return False

if __name__ == '__main__':
    content_dir = '/workspaces/CES/src/Celeste.Android/Content'
    output_file = '/workspaces/CES/src/Celeste.Android/Content/Content.mgcb'
    
    print("=" * 70)
    print("GERADOR CONTENT.MGCB")
    print("=" * 70)
    
    if generate_content_mgcb(content_dir, output_file):
        print("\n✅ Concluído!")
    else:
        print("\n❌ Erro!")
