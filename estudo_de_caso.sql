-- Estrutura do arquivo:
--   Q1. Análise histórica (janeiro a setembro/2026)
--   Q2. Diagnóstico: por que o investimento não melhorou o SLA?
--   Q3. Recomendação: o que deve mudar na política de incentivos
--   Q4. Projeção: impacto esperado para outubro a dezembro/2026
--
-- Premissas gerais:
--   Todos os horários estão em horário de Brasília (sem fuso).
--   SLA = completados com data_finalizacao <= data_objetivo / total de completados.
--   Disponibilidade = completados / total de pedidos.
--   Cancelamento por problema de frota: cancelado após 12,5% da janela
--   (data_objetivo - data_criacao), independentemente do motivo.
--   Investimento em incentivos é atribuído pelo mês de data_inicio do
--   incentivo (não data_saida do participante), conforme validado
--   contra os números do briefing (ago ~R$ 6,1 mil; set ~R$ 15,7 mil).

-- =====================================================================
-- Q1. ANÁLISE HISTÓRICA (JANEIRO A SETEMBRO/2026)
-- Como evoluíram a operação, a frota de entregadores e os incentivos?

-- Q1a. Evolução mensal consolidada da operação
-- Objetivo: mostrar a evolução do volume de pedidos, completados,
-- cancelados, disponibilidade, cancelamentos por problema de frota e SLA.
USE CASE_ENTREGAS;
SELECT
  DATE_FORMAT(p.data_criacao, '%Y-%m') AS mes,
  COUNT(*) AS total_pedidos,
  SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END) AS completados, 
  SUM(CASE WHEN p.status = 'cancelado' THEN 1 ELSE 0 END) AS cancelados,
  -- Disponibilidade = completados / total de pedidos
  ROUND(100.0 * SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END)
    / COUNT(*), 2) AS disponibilidade_pct,
  -- Cancelamento por problema de frota: cancelado após 12,5% da janela
  SUM(CASE WHEN p.status = 'cancelado'
    AND p.data_cancelamento IS NOT NULL
    AND TIMESTAMPDIFF(SECOND, p.data_criacao, p.data_cancelamento)
      > 0.125 * TIMESTAMPDIFF(SECOND, p.data_criacao, p.data_objetivo)
    THEN 1 ELSE 0 END) AS cancel_problema_frota,
  -- SLA = completados no prazo / total de completados
  SUM(CASE WHEN p.status = 'completado'
    AND p.data_finalizacao <= p.data_objetivo THEN 1 ELSE 0 END) AS sla_ok,
  ROUND(100.0 * SUM(CASE WHEN p.status = 'completado'
    AND p.data_finalizacao <= p.data_objetivo THEN 1 ELSE 0 END)
    / SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END), 2) AS sla_pct
FROM pedidos p
WHERE p.data_criacao >= '2026-01-01' AND p.data_criacao < '2026-10-01'
GROUP BY DATE_FORMAT(p.data_criacao, '%Y-%m')
ORDER BY mes;
-- Resultado: SLA cai de 92,48% (jan) para 85,69% (set). Disponibilidade
-- estável em ~77-78%. Cancelamentos por problema de frota crescem de
-- 1.235 (jan) para 1.627 (set).


-- Q1b. Evolução mensal da frota (média de disponíveis e em corrida)
-- Objetivo: mostrar se a frota online cresceu ou encolheu ao longo do ano.
SELECT
  DATE_FORMAT(f.data, '%Y-%m') AS mes,
  ROUND(AVG(f.entregadores_disponiveis), 1) AS media_disponiveis,
  ROUND(AVG(f.entregadores_em_corrida), 1) AS media_em_corrida,
  ROUND(AVG(f.entregadores_disponiveis + f.entregadores_em_corrida), 1)
    AS media_total_online,
  MAX(f.entregadores_disponiveis) AS pico_disponiveis,
  MAX(f.entregadores_em_corrida) AS pico_em_corrida
FROM frota_historico f
WHERE f.data >= '2026-01-01' AND f.data < '2026-10-01'
GROUP BY DATE_FORMAT(f.data, '%Y-%m')
ORDER BY mes;
-- Resultado: frota total estável (~9,5 média). Disponíveis caem levemente
-- de 7,0 para 6,5; em corrida sobe de 2,6 para 3,0.


-- Q1c. Evolução mensal dos incentivos
-- Objetivo: mostrar a evolução do número de promoções, participantes,
-- investimento, taxa de conclusão e tipos ao longo do ano.
use giross_case;
SELECT
  DATE_FORMAT(i.data_inicio, '%Y-%m') AS mes,
  COUNT(DISTINCT i.id) AS qtd_promocoes,
  SUM(CASE WHEN i.tipo = 'maximo' THEN 1 ELSE 0 END) AS tipo_maximo,
  SUM(CASE WHEN i.tipo = 'minimo' THEN 1 ELSE 0 END) AS tipo_minimo,
  COUNT(DISTINCT ip.entregador_id) AS participantes_unicos,
  COUNT(ip.entregador_id) AS participacoes_totais,
  ROUND(SUM(ip.valor_ganho), 2) AS investimento,
  SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END) AS concluidos,
  SUM(CASE WHEN ip.status = 'nao_concluiu' THEN 1 ELSE 0 END) AS nao_concluidos,
  ROUND(100.0 * SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END)
    / COUNT(ip.entregador_id), 1) AS pct_concluiu
FROM incentivos i
LEFT JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
WHERE i.data_inicio >= '2026-01-01' AND i.data_inicio < '2026-10-01'
GROUP BY DATE_FORMAT(i.data_inicio, '%Y-%m')
ORDER BY mes;
-- Resultado: promoções saltam de 21-25/mês (jan-ago) para 60 em set.
-- Investimento: ~R$ 5-6 mil/mês até ago, R$ 15,7 mil em set (2,6x).
-- Taxa de conclusão: 8-12% (muito baixa em todos os meses).


-- Q1d. SLA e disponibilidade por cidade e mês
-- Objetivo: identificar se a degradação do SLA é generalizada ou
-- concentrada em alguma cidade.
USE GIROSS_CASE;
SELECT
  p.cidade,
  DATE_FORMAT(p.data_criacao, '%Y-%m') AS mes,
  COUNT(*) AS total_pedidos,
  ROUND(100.0 * SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END)
    / COUNT(*), 2) AS disp_pct,
  ROUND(100.0 * SUM(CASE WHEN p.status = 'completado'
    AND p.data_finalizacao <= p.data_objetivo THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END), 0), 2)
    AS sla_pct,
  SUM(CASE WHEN p.status = 'cancelado'
    AND p.data_cancelamento IS NOT NULL
    AND TIMESTAMPDIFF(SECOND, p.data_criacao, p.data_cancelamento)
      > 0.125 * TIMESTAMPDIFF(SECOND, p.data_criacao, p.data_objetivo)
    THEN 1 ELSE 0 END) AS cancel_frota
FROM pedidos p
WHERE p.data_criacao >= '2026-01-01' AND p.data_criacao < '2026-10-01'
GROUP BY p.cidade, DATE_FORMAT(p.data_criacao, '%Y-%m')
ORDER BY p.cidade, mes;
-- Resultado: São Paulo: SLA cai de 91,54% (jan) para 80,84% (set),
--   -10,7 p.p. Outras cidades: estáveis (>90%) ou com leve queda.
--   O colapso do SLA é concentrado em São Paulo.
-- =====================================================================

-- Q2. DIAGNÓSTICO: POR QUE O AUMENTO DO INVESTIMENTO NÃO MELHOROU O SLA?

-- Q2a. Investimento em incentivos por cidade e mês
-- Objetivo: mostrar onde o dinheiro dos incentivos foi aplicado e se
-- houve concentração em São Paulo.
SELECT
  i.cidade,
  DATE_FORMAT(i.data_inicio, '%Y-%m') AS mes,
  COUNT(DISTINCT i.id) AS promocoes,
  COUNT(ip.entregador_id) AS participacoes,
  ROUND(SUM(ip.valor_ganho), 2) AS investimento,
  SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END) AS concluidos
FROM incentivos i
LEFT JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
WHERE i.data_inicio >= '2026-01-01' AND i.data_inicio < '2026-10-01'
GROUP BY i.cidade, DATE_FORMAT(i.data_inicio, '%Y-%m')
ORDER BY i.cidade, mes;
-- Resultado: São Paulo recebe R$ 13.671 em set (87% do total).
--   É exatamente onde o SLA mais caiu. Outras cidades: <R$ 700 em set.


-- Q2b. Investimento total vs SLA por cidade (jan-set 2026)
-- Objetivo: comparar o investimento total acumulado com a variação de SLA
-- por cidade, para evidenciar a desconexão entre gasto e resultado.
WITH invest AS (
  SELECT
    i.cidade,
    COUNT(DISTINCT i.id) AS total_promocoes,
    ROUND(SUM(ip.valor_ganho), 2) AS investimento_total
  FROM incentivos i
  JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
  WHERE i.data_inicio >= '2026-01-01' AND i.data_inicio < '2026-10-01'
  GROUP BY i.cidade
),
sla_data AS (
  SELECT
    p.cidade,
    DATE_FORMAT(p.data_criacao, '%Y-%m') AS mes,
    ROUND(100.0 * SUM(CASE WHEN p.status = 'completado'
      AND p.data_finalizacao <= p.data_objetivo THEN 1 ELSE 0 END)
      / SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END), 2) AS sla_pct
  FROM pedidos p
  WHERE p.data_criacao >= '2026-01-01' AND p.data_criacao < '2026-10-01'
  GROUP BY p.cidade, DATE_FORMAT(p.data_criacao, '%Y-%m')
)
SELECT
  inv.cidade,
  inv.total_promocoes,
  inv.investimento_total,
  ROUND(AVG(sla.sla_pct), 2) AS sla_medio,
  MAX(CASE WHEN sla.mes = '2026-01' THEN sla.sla_pct END) AS sla_jan,
  MAX(CASE WHEN sla.mes = '2026-09' THEN sla.sla_pct END) AS sla_set,
  ROUND(MAX(CASE WHEN sla.mes = '2026-09' THEN sla.sla_pct END)
    - MAX(CASE WHEN sla.mes = '2026-01' THEN sla.sla_pct END), 2) AS delta_sla
FROM invest inv
LEFT JOIN sla_data sla ON sla.cidade = inv.cidade
GROUP BY inv.cidade, inv.total_promocoes, inv.investimento_total
ORDER BY inv.investimento_total DESC;
-- Resultado: SP: R$ 50.560 investidos, SLA -10,7 p.p.
--   Porto Alegre: R$ 1.922, SLA +1,05 p.p. Mais investimento, pior resultado.


-- Q2c. Tipo de incentivo em São Paulo (ago vs set)
-- Objetivo: mostrar a composição dos incentivos por tipo (maximo/minimo)
-- em São Paulo nos meses de escalada.
SELECT
  i.tipo,
  DATE_FORMAT(i.data_inicio, '%Y-%m') AS mes,
  COUNT(DISTINCT i.id) AS promocoes,
  COUNT(ip.entregador_id) AS participacoes,
  ROUND(SUM(ip.valor_ganho), 2) AS investimento,
  SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END) AS concluidos,
  SUM(CASE WHEN ip.status = 'nao_concluiu' THEN 1 ELSE 0 END) AS nao_concluidos,
  ROUND(100.0 * SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END)
    / COUNT(ip.entregador_id), 1) AS pct_concluiu
FROM incentivos i
JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
WHERE i.cidade = 'São Paulo'
  AND i.data_inicio >= '2026-08-01' AND i.data_inicio < '2026-10-01'
GROUP BY i.tipo, DATE_FORMAT(i.data_inicio, '%Y-%m')
ORDER BY mes, i.tipo;
-- Resultado: em set, 89% do investimento foi em tipo 'minimo' (missão):
--   R$ 12.094,50 de R$ 13.671. Apenas 10,2% dos participantes concluíram.


-- Q2d. Pagamento por tipo e status (setembro 2026)
-- Objetivo: evidenciar que o tipo 'minimo' paga R$ 0 para não-concluintes,
-- gerando 2.417 participantes sem remuneração apesar do esforço.
SELECT
  i.tipo,
  ip.status,
  COUNT(*) AS qtd,
  ROUND(SUM(ip.valor_ganho), 2) AS total_pago,
  ROUND(AVG(ip.valor_ganho), 2) AS media_pago,
  MIN(ip.valor_ganho) AS min_pago,
  MAX(ip.valor_ganho) AS max_pago
FROM incentivo_participantes ip
JOIN incentivos i ON ip.incentivo_id = i.id
WHERE i.data_inicio >= '2026-09-01' AND i.data_inicio < '2026-10-01'
GROUP BY i.tipo, ip.status
ORDER BY i.tipo, ip.status;
-- Resultado: 'minimo' nao_concluiu: 2.417 participantes, R$ 0,00.
--   'minimo' concluiu: 239, R$ 12.656,75.
--   90% dos participantes de missão recebem ZERO.


-- Q2e. Evolução da frota em São Paulo (média mensal)
-- Objetivo: mostrar que a frota disponível encolheu em SP apesar dos
-- incentivos, enquanto a demanda cresceu.
SELECT
  DATE_FORMAT(f.data, '%Y-%m') AS mes,
  ROUND(AVG(f.entregadores_disponiveis), 1) AS media_disp,
  ROUND(AVG(f.entregadores_em_corrida), 1) AS media_corrida,
  ROUND(AVG(f.entregadores_disponiveis + f.entregadores_em_corrida), 1)
    AS media_total,
  ROUND(AVG(f.entregadores_em_corrida)
    / NULLIF(AVG(f.entregadores_disponiveis), 0), 2) AS ratio_corrida_disp
FROM frota_historico f
WHERE f.cidade = 'São Paulo'
  AND f.data >= '2026-01-01' AND f.data < '2026-10-01'
GROUP BY DATE_FORMAT(f.data, '%Y-%m')
ORDER BY mes;
-- Resultado: disponíveis caem de 17,5 (jan) para 14,1 (set), -19%.
--   Em corrida sobe de 7,9 para 9,1. Razão 0,45 -> 0,64 (frota mais
--   tensionada).


-- Q2f. Demanda vs cancelamentos sem entregador em São Paulo
-- Objetivo: mostrar que a demanda cresceu enquanto a oferta encolheu,
-- gerando mais cancelamentos por falta de entregador.

SELECT
  DATE_FORMAT(p.data_criacao, '%Y-%m') AS mes,
  COUNT(*) AS total_pedidos,
  ROUND(COUNT(*) / DAY(LAST_DAY(MAX(p.data_criacao))), 0) AS pedidos_por_dia,
  SUM(CASE WHEN p.status = 'cancelado'
    AND p.motivo_cancelamento = 'sem_entregador' THEN 1 ELSE 0 END)
    AS cancel_sem_entregador
FROM pedidos p
WHERE p.cidade = 'São Paulo'
  AND p.data_criacao >= '2026-01-01' AND p.data_criacao < '2026-10-01'
GROUP BY DATE_FORMAT(p.data_criacao, '%Y-%m')
ORDER BY mes;
-- Resultado: pedidos/dia sobe de 392 (jan) para 456 (set), +16,3%.
--   Cancelamentos 'sem_entregador': 273 -> 412, +51%.


-- Q2g. Desistências de entregadores em São Paulo por mês
-- Objetivo: mostrar que as desistências cresceram, indicando maior
-- tensão operacional.
SELECT
  DATE_FORMAT(h.data_evento, '%Y-%m') AS mes,
  SUM(CASE WHEN h.evento = 'aceite' THEN 1 ELSE 0 END) AS aceites,
  SUM(CASE WHEN h.evento = 'desistencia' THEN 1 ELSE 0 END) AS desistencias,
  ROUND(100.0 * SUM(CASE WHEN h.evento = 'desistencia' THEN 1 ELSE 0 END)
    / SUM(CASE WHEN h.evento = 'aceite' THEN 1 ELSE 0 END), 2)
    AS pct_desistencia
FROM historico_corrida h
JOIN pedidos p ON h.pedido_id = p.id
WHERE p.cidade = 'São Paulo'
  AND h.data_evento >= '2026-01-01' AND h.data_evento < '2026-10-01'
GROUP BY DATE_FORMAT(h.data_evento, '%Y-%m')
ORDER BY mes;
-- Resultado: desistências sobem de 8,50% (jan) para 9,71% (set).


-- Q2h. Eficiência do investimento (R$ por corrida completada)
-- Objetivo: mostrar que o custo por corrida completada saltou em
-- setembro, indicando desperdício.
SELECT
  op.mes,
  op.total_pedidos,
  op.completados,
  op.sla_pct,
  inc.investimento,
  inc.concluidos_incentivo,
  ROUND(inc.investimento / NULLIF(op.completados, 0), 4)
    AS rs_por_corrida_completada,
  ROUND(inc.investimento / NULLIF(inc.concluidos_incentivo, 0), 2)
    AS rs_por_concluinte,
  inc.participacoes,
  inc.pct_concluiu
FROM (
  SELECT
    DATE_FORMAT(p.data_criacao, '%Y-%m') AS mes,
    COUNT(*) AS total_pedidos,
    SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END) AS completados,
    ROUND(100.0 * SUM(CASE WHEN p.status = 'completado'
      AND p.data_finalizacao <= p.data_objetivo THEN 1 ELSE 0 END)
      / SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END), 2) AS sla_pct
  FROM pedidos p
  WHERE p.data_criacao >= '2026-01-01' AND p.data_criacao < '2026-10-01'
  GROUP BY DATE_FORMAT(p.data_criacao, '%Y-%m')
) op
JOIN (
  SELECT
    DATE_FORMAT(i.data_inicio, '%Y-%m') AS mes,
    ROUND(SUM(ip.valor_ganho), 2) AS investimento,
    SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END) AS concluidos_incentivo,
    COUNT(ip.entregador_id) AS participacoes,
    ROUND(100.0 * SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END)
      / COUNT(ip.entregador_id), 1) AS pct_concluiu
  FROM incentivos i
  JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
  WHERE i.data_inicio >= '2026-01-01' AND i.data_inicio < '2026-10-01'
  GROUP BY DATE_FORMAT(i.data_inicio, '%Y-%m')
) inc ON op.mes = inc.mes
ORDER BY op.mes;
-- Resultado: R$/corrida: 0,34 (jan-ago) -> 0,89 (set). Eficiência cai.


-- Q2i. Entregadores ativos vs participantes de incentivos em SP (set)
-- Objetivo: mostrar que muitos aprovados não estão ativos e que os
-- incentivos atraem adesão mas não convertem em corridas.
SELECT
  COUNT(DISTINCT ip.entregador_id) AS participantes_incentivo,
  (SELECT COUNT(DISTINCT p.entregador_id) FROM pedidos p
   WHERE p.cidade = 'São Paulo'
   AND p.data_finalizacao >= '2026-09-01' AND p.data_finalizacao < '2026-10-01'
   AND p.entregador_id IS NOT NULL) AS entregadores_ativos,
  (SELECT COUNT(*) FROM entregadores e
   WHERE e.cidade = 'São Paulo' AND e.status = 'aprovado') AS aprovados_total
FROM incentivo_participantes ip
JOIN incentivos i ON ip.incentivo_id = i.id
WHERE i.cidade = 'São Paulo'
  AND i.data_inicio >= '2026-09-01' AND i.data_inicio < '2026-10-01';
-- Resultado: 1.440 participantes de incentivo, apenas 588 ativos,
--   2.957 aprovados. 80% dos aprovados estão inativos.


-- Q2j. Novos entregadores aprovados por mês em São Paulo
-- Objetivo: verificar se os incentivos de 'Expansão' trouxeram novos
-- entregadores em quantidade significativa.
SELECT
  DATE_FORMAT(e.data_aprovacao, '%Y-%m') AS mes,
  COUNT(*) AS novos_aprovados
FROM entregadores e
WHERE e.cidade = 'São Paulo'
  AND e.data_aprovacao >= '2026-01-01' AND e.data_aprovacao < '2026-10-01'
GROUP BY DATE_FORMAT(e.data_aprovacao, '%Y-%m')
ORDER BY mes;
-- Resultado: 59-96 aprovados/mês (estável). Não houve salto em set.
-- =====================================================================

-- Q3. RECOMENDAÇÃO: O QUE DEVE MUDAR NA POLÍTICA DE INCENTIVOS

-- As consultas abaixo fornecem evidências adicionais que sustentam
-- a recomendação. A recomendação completa está no documento anexo.

-- Q3a. Análise de pico de demanda por hora em São Paulo (set 2026)
-- Objetivo: identificar os horários de pico e os buracos de SLA para
-- direcionar incentivos aos momentos certos.
SELECT
  HOUR(p.data_criacao) AS hora,
  COUNT(*) AS pedidos,
  SUM(CASE WHEN p.status = 'cancelado' THEN 1 ELSE 0 END) AS cancelados,
  ROUND(100.0 * SUM(CASE WHEN p.status = 'completado'
    AND p.data_finalizacao <= p.data_objetivo THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END), 0), 2)
    AS sla_pct,
  ROUND(AVG(f.entregadores_disponiveis), 1) AS disp_media,
  ROUND(AVG(f.entregadores_em_corrida), 1) AS corrida_media
FROM pedidos p
LEFT JOIN frota_historico f
  ON f.cidade = p.cidade
  AND f.data = DATE(p.data_criacao)
  AND f.hora = HOUR(p.data_criacao)
WHERE p.cidade = 'São Paulo'
  AND p.data_criacao >= '2026-09-01' AND p.data_criacao < '2026-10-01'
GROUP BY HOUR(p.data_criacao)
ORDER BY hora;
-- Resultado: pico de demanda 11h-13h e 19h. Pior SLA: 21h (69,15%),
--   20h (72,39%), 19h (76,52%). Frota disponível cai de 38,1 (10h)
--   para 10,0 (20h). O descompasso demanda-frota no período noturno
--   é a principal causa do SLA baixo.


-- Q3b. SLA por janela do dia em São Paulo (set 2026)
-- Objetivo: consolidar a análise por janela para justificar o foco
-- no período noturno.
SELECT
  CASE
    WHEN HOUR(p.data_criacao) BETWEEN 6 AND 11 THEN 'Manha (6-11h)'
    WHEN HOUR(p.data_criacao) BETWEEN 12 AND 17 THEN 'Tarde (12-17h)'
    WHEN HOUR(p.data_criacao) BETWEEN 18 AND 23 THEN 'Noite (18-23h)'
    ELSE 'Madrugada (0-5h)'
  END AS janela,
  COUNT(*) AS pedidos,
  SUM(CASE WHEN p.status = 'cancelado' THEN 1 ELSE 0 END) AS cancelados,
  ROUND(100.0 * SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END)
    / COUNT(*), 2) AS disp_pct,
  ROUND(100.0 * SUM(CASE WHEN p.status = 'completado'
    AND p.data_finalizacao <= p.data_objetivo THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN p.status = 'completado' THEN 1 ELSE 0 END), 0), 2)
    AS sla_pct
FROM pedidos p
WHERE p.cidade = 'São Paulo'
  AND p.data_criacao >= '2026-09-01' AND p.data_criacao < '2026-10-01'
GROUP BY 1
ORDER BY 1;
-- Resultado: Noite (18-23h): SLA 75,54%, 4.121 pedidos, 1.018 cancelados.
--   Manhã: SLA 86,41%. Tarde: SLA 80,57%. Madrugada: 83,33%.


-- Q3c. Comparação de eficiência: tipo maximo vs minimo (jan-set 2026)
-- Objetivo: demonstrar que o tipo 'maximo' tem maior taxa de conclusão
-- e paga por esforço parcial, enquanto 'minimo' gera desperdício.
SELECT
  i.tipo,
  COUNT(DISTINCT i.id) AS promocoes,
  COUNT(ip.entregador_id) AS participacoes,
  SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END) AS concluidos,
  ROUND(100.0 * SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END)
    / COUNT(ip.entregador_id), 1) AS pct_concluiu,
  ROUND(SUM(ip.valor_ganho), 2) AS investimento,
  ROUND(SUM(CASE WHEN ip.status = 'concluiu' THEN ip.valor_ganho ELSE 0 END), 2)
    AS pago_concluintes,
  ROUND(SUM(CASE WHEN ip.status = 'nao_concluiu' THEN ip.valor_ganho ELSE 0 END), 2)
    AS pago_nao_concluintes,
  ROUND(SUM(ip.valor_ganho)
    / NULLIF(SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END), 0), 2)
    AS custo_por_concluinte
FROM incentivos i
JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
WHERE i.data_inicio >= '2026-01-01' AND i.data_inicio < '2026-10-01'
GROUP BY i.tipo;
-- Resultado: 'maximo': 13,3% conclusão, paga R$ 12.514 a não-concluintes
--   (esforço parcial remunerado). 'minimo': 8,6% conclusão, R$ 0 para
--   não-concluintes (6.892 participantes recebem zero).


-- Q3d. Objetivos dos incentivos em São Paulo (setembro 2026)
-- Objetivo: mostrar a dispersão de objetivos em set, com 40 promoções
-- simultâneas, muitas sobrepostas e pouco focadas.
SELECT
  i.objetivo,
  i.tipo,
  COUNT(DISTINCT i.id) AS promocoes,
  COUNT(ip.entregador_id) AS participacoes,
  ROUND(SUM(ip.valor_ganho), 2) AS investimento,
  SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END) AS concluidos,
  ROUND(AVG(i.corridas_para_cumprir), 0) AS corridas_meta,
  ROUND(AVG(i.bonus_por_corrida), 2) AS bonus_por_corrida
FROM incentivos i
JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
WHERE i.cidade = 'São Paulo'
  AND i.data_inicio >= '2026-09-01' AND i.data_inicio < '2026-10-01'
GROUP BY i.objetivo, i.tipo
ORDER BY investimento DESC;
-- Resultado: 40 promoções em set, majoritariamente 'minimo' com
--   objetivos de Engajamento e Expansão. Muitas sobrepostas.


-- Q3e. Investimento por objetivo em São Paulo (acumulado jan-set 2026)
-- Objetivo: identificar quais objetivos consomem mais investimento
-- e sua taxa de conclusão.
SELECT
  i.objetivo,
  COUNT(DISTINCT i.id) AS promocoes,
  COUNT(ip.entregador_id) AS participacoes,
  ROUND(SUM(ip.valor_ganho), 2) AS investimento,
  SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END) AS concluidos,
  ROUND(100.0 * SUM(CASE WHEN ip.status = 'concluiu' THEN 1 ELSE 0 END)
    / COUNT(ip.entregador_id), 1) AS pct_concluiu
FROM incentivos i
JOIN incentivo_participantes ip ON ip.incentivo_id = i.id
WHERE i.cidade = 'São Paulo'
  AND i.data_inicio >= '2026-01-01' AND i.data_inicio < '2026-10-01'
GROUP BY i.objetivo
ORDER BY investimento DESC;
-- Resultado: Engajamento e Expansão concentram o investimento com
--   baixíssima taxa de conclusão (8-10%).
-- =====================================================================


-- RESUMO DA RECOMENDAÇÃO (Q3)
-- 1. MUDAR O TIPO PREDOMINANTE: Substituir 'minimo' (missão) por
--    'maximo' como tipo padrão. 'Maximo' paga por esforço parcial,
--    tem 13,3% de conclusão vs 8,6% do 'minimo', e não gera 90% de
--    participantes frustrados com R$ 0.

-- 2. FOCAR NO PERÍODO NOTURNO: Concentrar incentivos nas janelas
--    18h-23h em São Paulo, onde o SLA é 75,5% (vs 86,4% na manhã) e
--    a frota disponível cai pela metade. Bônus por corrida nesse
--    período deve ser 30-50% maior que o diurno.

-- 3. ATIVAR ENTREGADORES APROVADOS INATIVOS: Existem 2.957 aprovados
--    em SP, mas apenas 588 ativos (20%). Criar incentivo 'Reativação'
--    tipo maximo: bônus por corrida nas primeiras 10 corridas para
--    entregadores inativos há mais de 30 dias.

-- 4. REDUZIR O NÚMERO DE PROMOÇÕES SIMULTÂNEAS: Em setembro havia
--    40 promoções ativas simultaneamente em SP. Reduzir para 5-8
--    promoções bem focadas, evitando canibalização e dispersão.

-- 5. VINCULAR BÔNUS AO SLA: Adicionar um bônus de qualidade: o
--    entregador que completar corridas dentro do SLA recebe um
--    acréscimo de 20% no bônus. Isso alinha o incentivo ao objetivo
--    de negócio (SLA > 90%).

-- 6. CAP DE INVESTIMENTO POR CIDADE: Limitar o investimento mensal
--    por cidade a um teto baseado no gap de frota, não na demanda.
--    SP: teto de R$ 8-10 mil/mês (vs R$ 15,7 mil em set).

-- 7. DESCONTINUAR 'EXPANSÃO' COMO OBJETIVO DE INCENTIVO: Os dados
--    mostram que incentivos de Expansão não trouxeram novos
--    entregadores (aprovados estáveis em ~80/mês). Substituir por
--    programas de indicação e onboarding acelerado.
-- =====================================================================


-- Q4. PROJEÇÃO: IMPACTO ESPERADO PARA OUTUBRO A DEZEMBRO/2026

-- As consultas abaixo fornecem a base de cálculo para a projeção.
-- A projeção completa com premissas está no documento anexo.

-- Q4a. Base de cálculo: indicadores de setembro 2026 (ponto de partida)
-- Objetivo: estabelecer a linha de base para a projeção.
SELECT
  'Setembro 2026 (baseline)' AS cenario,
  22869 AS total_pedidos,
  17715 AS completados,
  85.69 AS sla_pct,
  77.46 AS disp_pct,
  15707.00 AS investimento,
  3071 AS participacoes,
  9.3 AS pct_concluiu
UNION ALL
SELECT
  'Sao Paulo apenas' AS cenario,
  13676 AS total_pedidos,
  10583 AS completados,
  80.84 AS sla_pct,
  77.41 AS disp_pct,
  13671.00 AS investimento,
  2493 AS participacoes,
  10.2 AS pct_concluiu;
-- Estes são os valores de setembro/2026 usados como baseline.

-- Q4b. Projeção: cenário atual (manter o modelo de setembro)
-- Objetivo: projetar o que acontece se nada mudar.
-- Premissas:
--   - Demanda mantida no nível de set (~22.869 pedidos/mês).
--   - Frota disponível continua caindo ~3% ao mês (tendência SP).
--   - Investimento mantido em ~R$ 15.700/mês com 60 promoções.
--   - Taxa de conclusão mantida em ~9,3%.
--   - SLA tende a piorar 1-2 p.p. ao mês pela degradação da frota.
SELECT
  mes AS mes,
  CASE mes
    WHEN 'Out/2026' THEN 86.0
    WHEN 'Nov/2026' THEN 84.0
    WHEN 'Dez/2026' THEN 82.0
  END AS sla_pct_projetado,
  CASE mes
    WHEN 'Out/2026' THEN 15707.00
    WHEN 'Nov/2026' THEN 15707.00
    WHEN 'Dez/2026' THEN 15707.00
  END AS investimento_projetado
FROM (
  SELECT 'Out/2026' AS mes
  UNION ALL SELECT 'Nov/2026'
  UNION ALL SELECT 'Dez/2026'
) t
ORDER BY mes;
-- Cenário atual: SLA projeta 86% -> 84% -> 82% (piora).
-- Investimento: R$ 15.707/mês (R$ 47.121 total no trimestre).


-- Q4c. Projeção: cenário recomendado
-- Objetivo: projetar o impacto da recomendação.
-- Premissas:
--   - Demanda mantida (~22.869 pedidos/mês).
--   - Investimento reduzido para R$ 8.000/mês (foco + eficiência).
--   - Tipo 'maximo' como padrão: taxa de conclusão sobe para ~13%.
--   - Foco no período noturno: SLA noturno de 75,5% -> 85% (out),
--     88% (nov), 90% (dez), pela ativação de entregadores inativos
--     e bônus por SLA.
--   - Ativação de ~5% dos 2.369 inativos/mês: +118 entregadores/mês.
--   - SLA diurno mantido em ~86-88%.
--   - SLA consolidado: média ponderada (~40% noturno, ~60% diurno).
SELECT
  mes AS mes,
  CASE mes
    WHEN 'Out/2026' THEN 87.5
    WHEN 'Nov/2026' THEN 89.5
    WHEN 'Dez/2026' THEN 90.5
  END AS sla_pct_projetado,
  CASE mes
    WHEN 'Out/2026' THEN 8000.00
    WHEN 'Nov/2026' THEN 8000.00
    WHEN 'Dez/2026' THEN 8000.00
  END AS investimento_projetado,
  CASE mes
    WHEN 'Out/2026' THEN 118
    WHEN 'Nov/2026' THEN 236
    WHEN 'Dez/2026' THEN 354
  END AS entregadores_ativados_acum
FROM (
  SELECT 'Out/2026' AS mes
  UNION ALL SELECT 'Nov/2026'
  UNION ALL SELECT 'Dez/2026'
) t
ORDER BY mes;
-- Cenário recomendado: SLA projeta 87,5% -> 89,5% -> 90,5%.
-- Investimento: R$ 8.000/mês (R$ 24.000 total no trimestre).
-- Economia: R$ 23.121 no trimestre (-49% vs cenário atual).
-- Meta de SLA > 90% atingida em dezembro.


-- Q4d. Comparativo dos dois cenários
-- Objetivo: sintetizar a diferença entre os cenários.
SELECT
  'Cenario Atual' AS cenario,
  86.0 AS sla_out,
  84.0 AS sla_nov,
  82.0 AS sla_dez,
  15707.00 AS invest_mensal,
  47121.00 AS invest_trimestre
UNION ALL
SELECT
  'Cenario Recomendado' AS cenario,
  87.5 AS sla_out,
  89.5 AS sla_nov,
  90.5 AS sla_dez,
  8000.00 AS invest_mensal,
  24000.00 AS invest_trimestre;
-- Resumo:
--   Cenário atual:      SLA 86% -> 84% -> 82%, R$ 47,1 mil
--   Cenário recomendado: SLA 87,5% -> 89,5% -> 90,5%, R$ 24,0 mil
--   Diferença: +8,5 p.p. no SLA de dez, -49% no investimento.
-- =====================================================================


-- PREMISSAS DA PROJEÇÃO (Q4)

-- 1. Demanda: mantida no nível de set/2026 (~22.869 pedidos/mês).
--    Premissa conservadora; se a demanda crescer, o impacto positivo
--    da recomendação é maior (frota melhor dimensionada).
--
-- 2. Frota: a recomendação de ativar inativos assume que 5% dos
--    2.369 aprovados inativos em SP retornam por mês (~118/mês),
--    acumulando 354 em 3 meses. Base: incentivo 'Reativação' tipo
--    maximo com bônus por corrida.
--
-- 3. SLA noturno: a melhoria de 75,5% para 90% em 3 meses é baseada
--    no fato de que a causa principal é falta de frota (não capacidade
--    de entrega). Com mais entregadores ativos no período e bônus
--    por SLA, a melhoria é factível.
--
-- 4. SLA diurno: mantido estável em 86-88%, pois a frota atual já
--    atende reasonably neste período.
--
-- 5. Investimento: R$ 8.000/mês é um teto baseado em 5-8 promoções
--    focadas (vs 60 em set), com tipo maximo (mais eficiente) e sem
--    desperdício com 'minimo' e 'Expansão'.
--
-- 6. Taxa de conclusão: estimada em ~13% (média histórica do tipo
--    maximo) vs 9,3% (set/2026 com minimo). Mais concluintes = mais
--    corridas incentivadas = mais valor gerado.
--
-- 7. Sazonalidade: outubro a dezembro inclui feriados (Natal, Ano
--    Novo) que podem aumentar demanda. A recomendação prevê promoções
--    específicas de Feriado tipo maximo para esses picos.

