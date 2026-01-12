---
layout: default
title: "Engenheiro de Software Sênior"
locale: pt-br
---

<header>
  <a href="{{ '/assets/pt_br/resume-short.pdf' | relative_url }}" target="_blank">baixe a versão curta do currículo</a> |
  <a href="{{ '/assets/pt_br/resume.pdf' | relative_url }}" target="_blank">baixe a versão completa do currículo</a>
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

{% capture softSkills %}{% include_relative soft-skills.md %}{% endcapture %}
{% capture technicalSkills %}{% include_relative technical-skills.md %}{% endcapture %}

---

<div class="two-columns">
  <div>{{ technicalSkills | markdownify }}</div>
  <div>{{ softSkills | markdownify }}</div>
</div>
