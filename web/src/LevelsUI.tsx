import { useEffect, useState } from "react"
import { fetchNui } from "./nui"

type CategoryData = {
  level: number
  xp: number
  nextLevelXP: number
}

export default function LevelsUI() {
  const [open, setOpen] = useState(true)
  const [levels, setLevels] = useState<Record<string, CategoryData>>({})

  const loadData = async () => {
    const data = await fetchNui("getAllXP")
    setLevels(data)
  }

  useEffect(() => {
    loadData()
  }, [])

  if (!open) return null

  return (
    <div className="fixed inset-0 flex items-center justify-center z-50">
      {/* Dark overlay */}
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm"></div>

      {/* Tablet Frame */}
      <div className="relative w-[800px] h-[450px] md:w-[90vw] md:h-[60vh] bg-[#111118] rounded-xl border border-[#33334d] shadow-lg flex flex-col p-4">
        
        {/* Header */}
        <div className="flex justify-between items-center mb-3 border-b border-[#33334d] pb-2">
          <h2 className="text-xl font-bold text-purple-400 uppercase tracking-wide">Levels</h2>
          <div className="flex gap-2">
            <button
              onClick={loadData}
              className="w-8 h-8 flex items-center justify-center bg-[#222233] border border-[#444466] rounded hover:bg-[#33334d] transition-colors text-purple-300"
            >
              ⟳
            </button>
            <button
              onClick={() => setOpen(false)}
              className="w-8 h-8 flex items-center justify-center bg-[#222233] border border-[#444466] rounded hover:bg-[#33334d] transition-colors text-purple-300"
            >
              ✕
            </button>
          </div>
        </div>

        {/* Levels Grid */}
        <div className="flex-1 grid grid-cols-2 gap-3 overflow-y-auto pr-2">
          {Object.entries(levels).map(([category, data]) => {
            const progress = Math.min((data.xp / data.nextLevelXP) * 100, 100)
            return (
              <div
                key={category}
                className="relative flex flex-col p-3 rounded-lg bg-[#1a1a24] border border-[#33334d] hover:border-purple-500 hover:bg-[#1f1f2a] transition-all"
              >
                <div className="flex justify-between items-center mb-1">
                  <span className="text-sm font-semibold text-purple-300 capitalize truncate max-w-[100px]">
                    {category}
                  </span>
                  <span className="text-xs font-semibold text-white bg-purple-500 rounded-full px-2 py-0.5">
                    Lvl {data.level}
                  </span>
                </div>

                <div className="text-[10.5px] text-gray-400 italic mb-2">
                  Progress your {category}!
                </div>

                <div className="relative h-4 w-full rounded-full bg-[#222233] overflow-hidden">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-purple-500 via-purple-400 to-purple-300 transition-all"
                    style={{ width: `${progress}%` }}
                  />
                  <span className="absolute w-full text-[9px] text-white text-center top-0 left-0">
                    {data.xp} / {data.nextLevelXP} XP
                  </span>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
