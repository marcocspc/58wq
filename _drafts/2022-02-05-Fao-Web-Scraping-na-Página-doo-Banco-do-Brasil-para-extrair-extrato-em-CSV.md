---
layout: post
title:  "Fazendo Web Scraping na Página do Banco do Brasil para extrair extrato em CSV"
date:  2022-02-05  2:40:58 UTC00 
categories: portugues linux python  
---

# Fazendo Web Scraping na Página do Banco do Brasil para extrair extrato em CSV 

Estou prestes a começar a automatizar minha vida financeira. Um dos passos essenciais é eu conseguir uma forma de obter meu extrato bancário automaticamente, para que eu não precise mais ficar preenchendo tabelas manualmente.

Desta forma, quero ver se consigo obter meu extrato do Banco do Brasil através da biblioteca Selenium e Python3. Minha intenção é automatizar tudo utilizando um container Linux, seja ele LXD ou Docker, mas não cobrirei esta parte nesta postagem. Por enquanto, vou me focar na parte de conseguir extrair automaticamente os dados de interesse.

Ah, e até agora o Banco do Brasil não possui APIs simples para que o usuário final possa extrair seus próprios dados. Portanto scraping por enquanto é a melhor saída.

## Instalando o Selenium
