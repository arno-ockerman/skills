# BE/NL secondhand market benchmarks

Rolling anchors for de gebruiker's dev-server and local-LLM searches. Re-check direct listings before purchase; EUR including VAT unless noted.

## Xeon-W workstations

| Configuration | Observed asking range | Decision anchor |
|---|---:|---|
| ThinkStation P520, W-2135 (6C/12T), 64 GB, 512 GB NVMe, small Quadro | €455-500 private | Strong complete base; buy ≤€480 after verifying 900 W PSU if a 24 GB GPU is planned |
| HP Z4 G4, W-2123 (4C/8T), 64 GB, 512 GB NVMe | ~€425 private | RAM-rich but CPU-light; bid €325-350, max €375 only with a cheap W-2145 upgrade path |
| HP Z4 G4, W-2133 (6C/12T), 64 GB, P2000, ~480 GB SSD | ~€579 private/reseller | Above the value line; target €450-475 and confirm SATA vs NVMe plus PSU |
| Dell Precision 5820, W-2123 (4C/8T), 32 GB ECC, P4000, 950 W | ~€390 private | Upgrade project; bid €300-325, max €350 because CPU and RAM both need work |
| HP Z4 G4 / P520 / 5820, W-2145 (8C/16T), 32 GB, 1 TB NVMe | €550-650 refurb | Good CPU but negotiate against 64 GB private systems; target ≤€520 |
| P520/5820, W-2133, 64 GB sold by refurb resellers | €850-900 | Skip: warranty markup overwhelms platform value |

## Buy limits

| Config | Koop tot | Goede deal | Overslaan boven |
|---|---:|---:|---:|
| Workstation + W-2135+ and 64 GB | €520 | €480 | €550 |
| Workstation + W-2145/W-2245 and 64 GB | €575 | €525 | €625 |
| Workstation + W-2135+ and 32 GB | €400 | €370 | €450 |
| Workstation with 4-core Xeon W | €350 | €320 | €400 |
| Ryzen 9 3900X loose CPU | €140 | €130 | €170 |
| Ryzen 9 5900X loose CPU | €190 | €170 | €230 |
| Xeon W-21xx/22xx CPU upgrade | €150 | €120 | €200 |

## GPU price anchors

| GPU | Good deal | Report/buy ceiling | Purpose |
|---|---:|---:|---|
| RTX 3060 12 GB used | €200-215 | €225 | Fast 7B/14B autocomplete/chat; not the preferred 30B agent tier |
| RTX 3060 12 GB sealed with verifiable invoice | €225 | €240 | Same capability; warranty only justifies a small premium |
| Tesla P40 24 GB including adapter/cooling | ≤€180 | €220; skip >€250 | Cheap 30B-capacity experiment with passive-cooling and Pascal-runtime work |
| RTX 3090 24 GB used | ≤€600 | €700 | Durable local agentic coding target |

Treat implausibly low high-end GPU listings as scam leads until pickup testing proves otherwise. For used GPUs require an observed stress test, GPU-Z/nvidia-smi identity, temperatures, artifact-free output, and a seller/account history check.

## Other anchors

- ECC RDIMM DDR4-2666 16/32 GB modules are commonly cheap used; price the final 64/128 GB configuration, not just the bare chassis.
- Mac mini 8 GB is unsuitable for the agent workload. For 16 GB Apple Silicon, value iOS/Xcode and idle power rather than pretending it equals a 64 GB x86 server.
- Reject old rack servers for a residential dev machine unless server-room noise and measured idle power are explicitly acceptable.

## Platform checks

- P520: verify 690 W vs 900 W PSU, installed PCIe power harness, RDIMM population, 2x M.2 presence, and physical GPU clearance.
- Z4 G4: verify 750/1000 W PSU variant and PCIe power connectors; some configurations are awkward for high-power consumer GPUs.
- Precision 5820: verify PSU wattage, M.2 carrier vs onboard storage, and whether the CPU is a 4-core placeholder or a useful W-2145+.
