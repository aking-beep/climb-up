import React from 'react'
import { useGame } from '../state/GameState'
import { ROUTES, fmtTime } from '../data/routes'
import { NewDataTag, SimTag } from '../components/ui'

const GRADE_ORDER = ['Lesson', '4', '5b', '6a', '6b', '6c', '7a']

/** Hero: highest grade sent. Everything else is supporting. */
export function ProfileSummary() {
  const { progress } = useGame()
  const sent = ROUTES.filter(r => (progress[r.id]?.sends ?? 0) > 0)
  const top = [...sent].sort((a, b) => GRADE_ORDER.indexOf(b.grade) - GRADE_ORDER.indexOf(a.grade))[0]
  const stars = ROUTES.reduce((s, r) => s + (progress[r.id]?.stars ?? 0), 0)
  const fastest = sent.filter(r => r.grade !== 'Lesson').sort((a, b) => progress[a.id].bestSeconds - progress[b.id].bestSeconds)[0]

  return (
    <div>
      <div className="flex items-end gap-5">
        <div>
          <div className="text-[12px] font-medium text-ink-muted">Highest grade sent</div>
          <div className="font-display text-[44px] leading-[0.95] text-ink">{top ? (top.grade === 'Lesson' ? 'L' : top.grade) : '—'}</div>
          <div className="whitespace-nowrap text-[13px] text-ink-soft">{top?.name}</div>
        </div>
        <dl className="grid flex-1 grid-cols-4 divide-x divide-paper-edge pb-1">
          <Stat k="Routes sent" v={`${sent.length}`} sub="of 7" />
          <Stat k="Stars" v={`${stars}`} sub="of 21" />
          <Stat k="Expeditions" v="1" sub="finished" />
          <Stat k="Summits" v="1" sub="Uhuru 5,895 m" />
        </dl>
      </div>

      <div className="mt-3 flex items-center justify-between">
        <div className="text-[12px] font-semibold text-ember">Personal records</div>
        <SimTag>Sample values</SimTag>
      </div>
      <ul className="mt-0.5 grid grid-cols-2 gap-x-6">
        <Rec k="Fastest send" v={fastest ? `${fastest.name} · ${fmtTime(progress[fastest.id].bestSeconds)}` : '—'} />
        <Rec k="Daily streak" v="4 days (best 6)" />
        <Rec k="Best expedition" v="412 leader points · Machame" />
        <Rec k="Artifacts brought home" v="7 of 24" />
        <Rec k="Metres climbed, all time" v="1,284 m" isNew />
        <Rec k="Days on the mountain" v="15" isNew />
      </ul>

      <div className="mt-2.5 flex items-center gap-4 whitespace-nowrap text-[12px] text-ink-muted">
        <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-spruce" /> From existing saves (crag, daily, records)</span>
        <span className="flex items-center gap-1.5"><NewDataTag /> Needs a new persistent record</span>
      </div>
    </div>
  )
}

function Stat({ k, v, sub }: { k: string; v: string; sub: string }) {
  return (
    <div className="min-w-0 px-2.5 first:pl-0">
      <dt className="text-[12px] text-ink-muted">{k}</dt>
      <dd className="tabular font-display text-[26px] leading-tight text-ink">{v}</dd>
      <dd className="whitespace-nowrap text-[12px] text-ink-muted">{sub}</dd>
    </div>
  )
}

function Rec({ k, v, isNew }: { k: string; v: string; isNew?: boolean }) {
  return (
    <li className="min-w-0 border-b border-paper-edge/70 py-1">
      <span className="flex h-5 items-center gap-1.5 whitespace-nowrap text-[12px] text-ink-muted">
        {!isNew && <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-spruce" />}
        <span className="truncate">{k}</span>
        {isNew && <NewDataTag className="ml-auto shrink-0 !h-[18px]" />}
      </span>
      <span className="block truncate text-[13px] font-medium leading-[18px] text-ink">{v}</span>
    </li>
  )
}
