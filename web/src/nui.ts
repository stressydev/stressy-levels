const isBrowser = !("GetParentResourceName" in window)

export const fetchNui = async (event: string) => {
  if (isBrowser) {
    if (event === "getAllXP") {
      return {
        police: { level: 3, xp: 120, nextLevelXP: 300 },
        criminal: { level: 5, xp: 80, nextLevelXP: 500 },
        driving: { level: 2, xp: 40, nextLevelXP: 200 },
        fitness: { level: 7, xp: 410, nextLevelXP: 800 },
      }
    }
    return true
  }

  return fetch(`https://${GetParentResourceName()}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  }).then((res) => res.json())
}
