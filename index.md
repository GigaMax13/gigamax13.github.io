---
layout: default
title: "Maximiliano Dalla Porta - Software Engineer"
# locale:
---

{% include_relative resume.md %}

{% capture softSkills %}{% include_relative soft-skills.md %}{% endcapture %}
{% capture technicalSkills %}{% include_relative technical-skills.md %}{% endcapture %}

---

<div class="two-columns">
  <div>{{ technicalSkills | markdownify }}</div>
  <div>{{ softSkills | markdownify }}</div>
</div>
