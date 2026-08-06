# Turn tab-separated host rows on stdin into a JSON array of host objects.
[inputs | split("\t")
  | {alias: .[0], hostname: .[1], user: .[2], port: .[3]}]
