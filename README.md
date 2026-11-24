<p align="center">
  <img src="assets/banner.jpg" alt="Aetheron Shaders" width="100%" />
</p>

<h1 align="center">Aetheron</h1>

<p align="center">
  Shader pack para Minecraft focado em iluminação natural, atmosfera densa e boa performance em GPUs modernas.
</p>

<p align="center">
  <a href="https://github.com/SantosFktt/Aetheron/releases/latest"><img src="https://img.shields.io/github/v/release/SantosFktt/Aetheron?label=release&style=flat&color=2563eb" alt="Latest Release" /></a>
  <img src="https://img.shields.io/badge/minecraft-1.20%2B%20%7C%201.12.2-16a34a?style=flat" alt="Minecraft Versions" />
  <img src="https://img.shields.io/badge/loaders-Iris%20%7C%20OptiFine-475569?style=flat" alt="Loaders" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-64748b?style=flat" alt="License" /></a>
</p>

---

## Sobre o projeto

O Aetheron é um shader pack escrito do zero em GLSL, buscando um meio-termo entre a iluminação limpa e o acabamento de água do **Photon** com o céu e as nuvens volumétricas do **Bliss**.

O projeto mantém duas bases separadas em vez de tentar forçar compatibilidade com `#ifdef` em um único código:

- **`modern/`** — Minecraft 1.20.x–1.21.x+ usando Iris + Sodium (`#version 330 compatibility`, IDs pós-flattening, `dimension.properties`, `entity.properties`).
- **`legacy_1.12.2/`** — Minecraft 1.12.2 no OptiFine HD U G5+ (`#version 120`, limite de 8 color attachments, IDs pré-flattening).

---

## Download e instalação

Baixe o `.zip` correspondente na página de [Releases](https://github.com/SantosFktt/Aetheron/releases/latest) e coloque direto na pasta `.minecraft/shaderpacks/` (sem extrair).

- **1.20.x / 1.21.x+ (Fabric ou NeoForge com Sodium + Iris):** use `Aetheron-Modern-Iris-1.20+.zip`
- **1.12.2 (OptiFine HD U G5+):** use `Aetheron-Legacy-OptiFine-1.12.2.zip` *(desative o Fast Render nas opções de desempenho do OptiFine)*

Dentro do jogo, abra as opções do shader e escolha entre os perfis **Low**, **Medium** ou **Ultra**. Todas as opções individuais continuam editáveis depois de selecionar um perfil.

---

## O que tem implementado

- **Atmosfera e céu:** espalhamento Rayleigh + Mie + absorção de ozônio, transição contínua de dia/pôr do sol/noite, disco solar com limb darkening, lua com fases reais (`moonPhase`), estrelas e céus próprios para Nether e End.
- **Nuvens:** camada 2D analítica no Low; raymarching volumétrico 3D (Perlin-Worley) com auto-sombreamento e camada cirrus no Medium e Ultra.
- **Iluminação e sombras:** shadow map distorcido até 4K, Vogel-disk PCF (Low/Medium) e PCSS com penumbra variável (Ultra), contact shadows em screen-space, sombras coloridas em vitrais, foliage SSS, GTAO, SSIL (GI difuso de 1 bounce), luz dinâmica na mão e poças em dias de chuva.
- **Água:** ondas multi-oitava, pingos de chuva, refração, absorção Beer-Lambert, cáusticas subaquáticas e reflexos SSR com refinamento binário + fallback de céu/nuvens.
- **Névoa e vegetação:** god rays amostrados no shadow map, névoa por altura, perspectiva atmosférica e vento por vértice sincronizado com o shadow pass.
- **Pós-processamento:** bloom em duas escalas (Karis), exposição automática, 4 tonemappers (Aetheron Filmic, ACES, AgX, Uncharted 2), TAA com variance clamping em YCoCg, CAS sharpening, DoF e motion blur opcionais.

---

## Perfis

| Configuração | Low | Medium | Ultra |
| :--- | :--- | :--- | :--- |
| Shadow resolution | 1024 | 2048 | 4096 |
| Shadow distance | 128 | 192 | 256 |
| Filtro de sombra | PCF (5 taps) | PCF (9 taps) | PCSS (6 + 14 taps) |
| Nuvens | Analíticas 2D | Volumétricas (18 steps) | Volumétricas 3D (32 steps + 4 sun) |
| Névoa volumétrica | 7 steps | 12 steps | 20 steps |
| Reflexos (SSR) | 12 steps | 22 steps | 36 steps (5 binários) |
| AO / SSIL | 4 taps / Off | 8 taps / 4 taps | 12 taps / 8 taps |
| Anti-aliasing | Off | TAA + CAS | TAA + CAS |

O preset **Ultra** foi calibrado mirando uma **RTX 5070 + Ryzen 7 9800X3D** em 1440p. Detalhes por pass de GPU estão em [`performance_profiles/README.md`](performance_profiles/README.md).

---

## Estrutura do repositório

```text
modern/                 # Iris 1.20+ (GLSL 330 compatibility)
legacy_1.12.2/          # OptiFine 1.12.2 (GLSL 120)
performance_profiles/   # Presets Low / Medium / Ultra
shared_documentation/   # Docs do pipeline, compatibilidade e configuração
tools/                  # Validador com glslangValidator e script de empacotamento
dist/                   # .zip gerados prontos para uso
```

## Build e validação local

Se editar algum arquivo `.glsl`, dá para validar todas as combinações de presets e dimensões com o `glslangValidator` e regerar os `.zip`:

```bash
python3 tools/validate_shaders.py --edition all
python3 tools/package_releases.py
```

---

## Documentação

- [Arquitetura do pipeline](shared_documentation/ARCHITECTURE.md)
- [Diferenças entre Modern e Legacy 1.12.2](shared_documentation/COMPATIBILITY.md)
- [Guia de instalação](shared_documentation/INSTALLATION.md)
- [Lista de opções e menus](shared_documentation/CONFIGURATION.md)
- [Otimização e profiling de GPU](shared_documentation/PERFORMANCE_AND_OPTIMIZATION.md)
- [Validação e checklist de testes](shared_documentation/TESTING_AND_QA.md)

Licenciado sob [MIT](LICENSE).
