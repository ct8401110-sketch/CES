#!/usr/bin/env python3
"""
Gerador de mipmaps de ícone Android
Cria ícones em múltiplas densidades a partir de uma imagem de origem
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Erro: Pillow não instalado. Execute: pip install Pillow")
    sys.exit(1)

# Definições de densidades Android
ICON_SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

def generate_mipmaps(input_image_path: str, output_dir: str) -> bool:
    """
    Gera mipmaps de ícone para Android a partir de uma imagem de origem
    
    Args:
        input_image_path: Caminho do ícone original
        output_dir: Diretório para os arquivos de saída
    
    Returns:
        True se sucesso, False se erro
    """
    try:
        # Carregar imagem original
        if not os.path.exists(input_image_path):
            print(f"Erro: Arquivo não encontrado: {input_image_path}")
            return False
        
        original_image = Image.open(input_image_path)
        print(f"Imagem original carregada: {original_image.size} pixels")
        print(f"Formato: {original_image.format}")
        
        # Converter para RGBA se necessário (para transparência)
        if original_image.mode != 'RGBA':
            original_image = original_image.convert('RGBA')
            print(f"Convertido para RGBA")
        
        # Criar estrutura de diretórios
        for density_dir in ICON_SIZES.keys():
            full_path = os.path.join(output_dir, density_dir)
            os.makedirs(full_path, exist_ok=True)
            print(f"Diretório criado: {full_path}")
        
        # Gerar ícones em múltiplas densidades
        for density_dir, size in ICON_SIZES.items():
            # Redimensionar com qualidade alta (LANCZOS)
            resized_image = original_image.resize(
                (size, size),
                Image.Resampling.LANCZOS
            )
            
            # Salvar em PNG (suporta transparência)
            output_path = os.path.join(output_dir, density_dir, 'ic_launcher.png')
            resized_image.save(output_path, 'PNG', optimize=True)
            
            print(f"✓ Gerado: {density_dir}/ic_launcher.png ({size}x{size}px)")
        
        print("\n✅ Todos os mipmaps foram gerados com sucesso!")
        return True
        
    except Exception as e:
        print(f"Erro ao processar ícone: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    # Caminhos
    input_image = '/tmp/app_icon_original.jpg'
    resources_dir = '/workspaces/CES/src/Celeste.Android/Resources'
    
    print("=" * 70)
    print("GERADOR DE MIPMAPS - ÍCONE ANDROID")
    print("=" * 70)
    print()
    
    if generate_mipmaps(input_image, resources_dir):
        print()
        print("=" * 70)
        print("Estrutura de diretórios criada:")
        print("=" * 70)
        for root, dirs, files in os.walk(resources_dir):
            level = root.replace(resources_dir, '').count(os.sep)
            indent = ' ' * 2 * level
            print(f'{indent}{os.path.basename(root)}/')
            subindent = ' ' * 2 * (level + 1)
            for file in files:
                print(f'{subindent}{file}')
        sys.exit(0)
    else:
        sys.exit(1)
