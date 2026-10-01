# Design system

The dashboards are built from a small design system, designed before any page was coded and checked against during QA. It has six layers, each built on the one before: principles, foundations, chart grammar, components, page templates and applied screens.

Everything is also in one file: [design-system.pdf](design-system.pdf) (34 pages).

> The applied screens carry illustrative values from the design phase. The [live dashboard](https://dixonalex.github.io/gtm-de/) is the source of truth for the numbers.

**Contents:** [Principles](#1--principles) · [Foundations](#2--foundations) · [Chart grammar](#3--chart-grammar) · [Components](#4--components) · [Page templates](#5--page-templates) · [Applied screens](#6--applied-screens)

## 1 · Principles

Pages are organized by reader and decision, not by dataset. Each of four authors contributes one rule; when two rules conflict, the one closer to the reader's decision wins. House rules settle what the canon doesn't, and a before-and-after shows the same data with and without the rules.

![The audience rule](1-principles/audience.png)
![Four canon rules](1-principles/canon.png)
![House rules](1-principles/house-rules.png)
![In practice: before and after](1-principles/do-and-dont.png)

## 2 · Foundations

Color, type, space and number formats. Status colors carry verdicts only, never categories, and red and green always travel with a sign or label. The type choice is recorded as a decision, with the options that lost.

![Color](2-foundations/color.png)
![Type](2-foundations/type.png)
![Space](2-foundations/space.png)
![Formats](2-foundations/formats.png)
![Decision record: type exploration](2-foundations/decision-record-type.png)

## 3 · Chart grammar

The anatomy every chart shares, the forms allowed and what each is for, and the rules that hold for all of them.

![Anatomy](3-chart-grammar/anatomy.png)
![Forms](3-chart-grammar/forms.png)
![Always, never](3-chart-grammar/always-never.png)

## 4 · Components

Ten components, each specified with its states and the rule it enforces. The live [component gallery](https://dixonalex.github.io/gtm-de/dev) renders the built versions.

![C1 · Page header](4-components/c01-page-header.png)
![C2 · KPI tile](4-components/c02-kpi-tile.png)
![C3 · Variance table](4-components/c03-variance-table.png)
![C4, C5 · Caveat and definition](4-components/c04-c05-caveat-definition.png)
![C6 · Exception worklist](4-components/c06-exception-worklist.png)
![C7 · Review-queue row](4-components/c07-review-queue-row.png)
![C8 · Status chip](4-components/c08-status-chip.png)
![C9 · Slicing](4-components/c09-slicing.png)
![C10 · Drill drawer, commentary, top movers](4-components/c10-drill-drawer-commentary-movers.png)

## 5 · Page templates

Six rules that hold on every page, the slices each page offers, and one template per reader.

![Every template](5-page-templates/shared-rules.png)
![T1 · Executive monthly](5-page-templates/t1-executive-monthly.png)
![T2 · Sales weekly](5-page-templates/t2-sales-weekly.png)
![T3 · Deal Desk daily](5-page-templates/t3-deal-desk-daily.png)
![T4 · Finance month-end](5-page-templates/t4-finance-month-end.png)
![T5 · Data health, continuous](5-page-templates/t5-data-health-continuous.png)

## 6 · Applied screens

The templates filled with data, as designed. Compare each with its live page.

| Screen | Live page |
|---|---|
| ![T1 Executive](6-applied-screens/t1-executive.png) | [Executive](https://dixonalex.github.io/gtm-de/) |
| ![T2 Sales](6-applied-screens/t2-sales.png) | [Sales](https://dixonalex.github.io/gtm-de/sales) |
| ![T3 Deal Desk](6-applied-screens/t3-deal-desk.png) | [Deal Desk](https://dixonalex.github.io/gtm-de/deal-desk) |
| ![T4 Finance](6-applied-screens/t4-finance.png) | [Finance](https://dixonalex.github.io/gtm-de/finance) |
| ![T5 Data health](6-applied-screens/t5-data-health.png) | [Data health](https://dixonalex.github.io/gtm-de/data-health) |

Two states of the Executive page. Filtering is live ([Enterprise](https://dixonalex.github.io/gtm-de/?segment=Enterprise)); the drill drawer is designed but not yet built.

![T1 Executive, filtered to Enterprise](6-applied-screens/t1-executive-enterprise.png)
![T1 Executive, drill panel open on Churn](6-applied-screens/t1-executive-drill-churn.png)
