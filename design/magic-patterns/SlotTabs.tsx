import React from 'react'
import { Shirt, HardHat, Backpack, Link2, Package, Cable, UserRound } from 'lucide-react'

export type Slot = 'body' | 'jacket' | 'headwear' | 'pack' | 'harness' | 'chalk' | 'rope'

const SLOTS: { id: Slot; label: string; Icon: React.ComponentType<{ size?: number }> }[] = [
  { id: 'body', label: 'Climber', Icon: UserRound },
  { id: 'jacket', label: 'Jacket', Icon: Shirt },
  { id: 'headwear', label: 'Headwear', Icon: HardHat },
  { id: 'pack', label: 'Backpack', Icon: Backpack },
  { id: 'harness', label: 'Harness', Icon: Link2 },
  { id: 'chalk', label: 'Chalk bag', Icon: Package },
  { id: 'rope', label: 'Rope', Icon: Cable },
]

export function SlotTabs({ slot, onPick }: { slot: Slot; onPick: (s: Slot) => void }) {
  return (
    <div className="flex w-[132px] shrink-0 flex-col gap-0.5 border-r border-paper-edge bg-paper-sunk/60 p-1.5">
      {SLOTS.map(({ id, label, Icon }) => (
        <button
          key={id}
          onClick={() => onPick(id)}
          aria-pressed={slot === id}
          className={`flex h-[48px] items-center gap-2 rounded-[8px] px-2 text-left text-[13px] font-medium leading-tight transition-colors duration-150 ${slot === id ? 'bg-spruce text-spruce-ink' : 'text-ink-soft hover:bg-paper-raised'}`}
        >
          <Icon size={18} />
          <span>{label}</span>
        </button>
      ))}
    </div>
  )
}
