# Schema des connexions switches comprends les vlans et les connextions entre les equipements physiques

### Switch S1 (Salle)

```md
| Port | VLAN  |
| ---- | ----- |
| 1    | Trunk |
| 2    | Trunk |
| 3    | 10    |
| 4    | 10    |
| 5    | 10    |
| 6    | 20    |
| 7    | 20    |
```

### Switch S2 (Baie)

```md
| Port | VLAN  |
| ---- | ----- |
| 1    | R     |
| 2    | S1-S2 |
| 3    | —     |
| 4    | PC    |
| 5    | PC    |
| 6    | PC    |
| 7    | Hub   |
| 8    | —     |
```

### Router (R)

```md
| Port | VLAN |
| ---- | ---- |
| 1    | WAN  |
| 2    | S1   |
| 3    | S2   |
| 4    | AP   |
| 5    | —    |
| 6    | —    |
```

### Panel / Bridge (B B)

```md
| Port | VLAN  |
| ---- | ----- |
| J1   | WAN   |
| 5    | S1-S2 |
| 6    | AP-R  |
| 7    | HUB   |
| 8    | S1-R  |
| 1    | PC    |
| 2    | PC    |
| 3    | PC    |
| 4    | PC    |
```
