"""Extrator Portal de Dados Abertos da ANVISA (CSV).

Responsável por:
- Detectar encoding (UTF-8 / ISO-8859-1) e delimitador (;).
- Converter para UTF-8 e normalizar campos numéricos/decimais.
- Preparar dados de MEDICAMENTO para a camada de staging.
"""
