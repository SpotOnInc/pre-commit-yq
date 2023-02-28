---
name: Bug report
about: Create a bug report
labels:
- bug
---

<!--
Thank you for helping to improve pre-commit-yq!

Please be sure to search for open issues before raising a new one. We use issues
for bug reports and feature requests. Please note, this template is for bugs
report, not feature requests.
-->

### Describe the bug

<!--
Please let us know what behavior you expected and how pre-commit-yq diverged
from that behavior.
-->


### How can we reproduce it?

<!--
Help us to reproduce your bug as succinctly and precisely as possible. Any and
all steps or script that triggers the issue are highly appreciated!

Do you have long logs to share? Please use collapsible sections, that can be created via:

<details><summary>SECTION_NAME</summary>

```bash
YOUR_LOG_HERE
```

</details>
-->


### Environment information


```bash
Insert here output of next command:

echo -e "
bash:
$(bash --version)
\n\npatch:
$(patch --version)
\n\nyq:
$(yq --version)
\n\nyq docker:
$(docker images mikefarah/yq)
"
```
