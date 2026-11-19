# 📦 Análise de Incentivos a Entregadores

Estudo de caso sobre a operação de entregas entre **janeiro e setembro de 2026**. A pergunta central: **por que investir mais em incentivos não melhorou o SLA?**

> ⚠️ Estudo de caso desenvolvido em processo seletivo. Todos os dados são **fictícios**.

---

## 🎯 Contexto e problema

Uma empresa de entregas aumentou o investimento em incentivos a entregadores, mas a qualidade da operação não acompanhou. O objetivo foi diagnosticar a causa, recomendar mudanças na política de incentivos e projetar o impacto para outubro a dezembro de 2026.

## 🔎 Principais achados

| Indicador | Resultado |
|---|---|
| Investimento mensal em incentivos | **2,6x maior** (de ~R$ 5–6 mil em jan–ago para R$ 15,7 mil em set) |
| SLA | **–6,8 p.p.** (de 92,5% em janeiro para 85,7% em setembro) |
| Custo por corrida completada | **R$ 0,89** em setembro, contra R$ 0,34 de jan a ago |
| Cancelamentos por falta de frota | **1.235 → 1.627** por mês |
| Disponibilidade (pedidos atendidos) | Estável em ~77–78% |
| Concentração geográfica | São Paulo recebeu 87% do investimento de setembro e teve a maior queda de SLA (–10,7 p.p.) |
| Modelo de missão | ~90% dos participantes não concluem a meta e não recebem pagamento |

## 💡 Recomendação

Menos promoções, **pagamento por esforço**, foco no **período noturno** e **reativação de entregadores parados**.

## 🗂️ Estrutura do repositório

```
├── sql/
│   └── estudo_de_caso.sql           # Q1 a Q4: histórico, diagnóstico, recomendação e projeção
├── dashboard/
│   └── dashboard.pbix               # Dashboard em Power BI
├── apresentacao/
│   ├── operacao_entregas.pptx       # Apresentação para a diretoria
│   └── operacao_entregas.pdf        # Mesma apresentação em PDF
└── imagens/                         # Prints do dashboard
```

## 🧪 Como o SQL está organizado

- **Q1. Análise histórica:** evolução mensal de pedidos, SLA, disponibilidade, frota e incentivos
- **Q2. Diagnóstico:** por que o investimento não melhorou o SLA
- **Q3. Recomendação:** o que mudar na política de incentivos
- **Q4. Projeção:** impacto esperado para outubro a dezembro de 2026

**Definições usadas:**
- **SLA** = completados com `data_finalizacao <= data_objetivo` ÷ total de completados
- **Disponibilidade** = completados ÷ total de pedidos
- **Cancelamento por problema de frota** = cancelado após 12,5% da janela (`data_objetivo - data_criacao`)
- **Investimento** atribuído pelo mês de `data_inicio` do incentivo

## 🛠️ Habilidades demonstradas

- SQL analítico: agregações, `CASE WHEN`, CTEs e métricas de negócio
- Modelagem e visualização em Power BI
- Diagnóstico a partir de dados e construção de recomendação
- Comunicação executiva para a diretoria

## 📸 Prévia

<img width="1225" height="538" alt="image" src="https://github.com/user-attachments/assets/de96208b-0a28-4e33-b588-b530e01acb3d" />
<img width="902" height="504" alt="image" src="https://github.com/user-attachments/assets/accafeb3-8059-44a2-90ea-1df11cd53a3c" />
<img width="906" height="501" alt="image" src="https://github.com/user-attachments/assets/c83d0b3e-0605-4d2a-bf5b-b6a298b0ae2a" />


## 👤 Autor

**Wellington Cruz**
Analista de Dados | BI | Negócios | Requisitos

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://linkedin.com/in/wellingtonsscruz)
[![E-mail](https://img.shields.io/badge/E--mail-EA4335?style=flat&logo=gmail&logoColor=white)](mailto:wellingtonsscruz@gmail.com)
