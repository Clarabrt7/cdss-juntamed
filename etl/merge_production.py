"""Estágio 2 do ETL: Migração atômica de Staging para Produção (BEGIN ... COMMIT).

Responsável por:
- CNES/ANVISA: INSERT ... ON CONFLICT (chave) DO UPDATE SET ...
- MIMIC-IV: Deduplicação via ROW_NUMBER() OVER (PARTITION BY hadm_id, itemid, charttime ORDER BY charttime DESC).
- Executar dentro de transação única ACID.
"""
