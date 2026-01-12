---
layout: default
title: "Engenheiro de Software Sênior"
locale: pt-br
---

<header>
  <span>Download -</span>
  <a href="{{ '/assets/pt_br/resume-short.pdf' | relative_url }}" target="_blank" title="Baixar versão resumida do currículo">[ Currículo Resumido (PDF)</a>
  <span>|</span>
  <a href="{{ '/assets/pt_br/resume.pdf' | relative_url }}" target="_blank" title="Baixar versão completa do currículo">Currículo (PDF) ]</a>
</header>

<div class="switch-language">
  <a class="flag disabled" href="/" title="English version">
    <img src="{{ '/assets/icons/en.png' | relative_url }}"/>
  </a>
  <a class="flag" href="/pt_br" title="Versão em Português">
    <img src="{{ '/assets/icons/pt_br.png' | relative_url }}"/>
  </a>
</div>

{% include_relative resume.md %}
