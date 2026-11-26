"""Estágio 1 do ETL: Carga e sanitização nas tabelas STG_*.

Responsável por:
- Aplicar defaults em colunas secundárias.
- Rejeitar registros sem chaves/atributos essenciais gravando em etl_audit_log.
- Carregar registros válidos nas tabelas STG_*.
"""
