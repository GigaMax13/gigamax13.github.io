---
layout: default
title: "Maximiliano Dalla Porta - Senior Software Engineer"
locale: en
---

<header>
  <a href="{{ '/assets/resume-short.pdf' | relative_url }}" target="_blank">download the resume short version</a> |
  <a href="{{ '/assets/resume.pdf' | relative_url }}" target="_blank">download the resume full version</a>
</header>

<div class="switch-language">
  <a class="flag" href="/" title="English version">
    <img src="{{ '/assets/icons/en.png' | relative_url }}"/>
  </a>
  <a class="flag disabled" href="/pt_br" title="Versão em Português">
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
