import json
import subprocess
import os

PLAN_FILE = "data/agent-plan.json"

print("=======================================")
print("MSC SEO OPERATOR AGENT")
print("=======================================")

if not os.path.exists(PLAN_FILE):
    print("No agent plan found.")
else:
    with open(PLAN_FILE) as f:
        plan = json.load(f)

    clusters = plan.get("expand_clusters", [])
    pages = plan.get("improve_pages", [])

    print("Clusters to expand:", clusters)
    print("Pages to improve:", pages)

print("=======================================")
print("Running cluster expansion...")
print("=======================================")

subprocess.run(["bash", "scripts/cluster-expander.sh"])

print("=======================================")
print("Running internal linker...")
print("=======================================")

subprocess.run(["bash", "scripts/internal-linker.sh"])

print("=======================================")
print("Agent completed")
print("=======================================")
