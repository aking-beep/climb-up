import React from 'react'
import { motion } from 'framer-motion'
import { ChevronLeft, Star } from 'lucide-react'

/* Buttons ---------------------------------------------------------------
   Minimum touch target 48 dp everywhere. Press feedback: scale 0.97, 120 ms. */

type BtnProps = React.ButtonHTMLAttributes<HTMLButtonElement> & { size?: 'md' | 'lg' }

export function PrimaryButton({ className = '', size = 'md', children, ...rest }: BtnProps) {
  return (
    <button
      {...rest}
      className={`inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-[6px] bg-spruce font-display text-spruce-ink shadow-[0_2px_0_#0f211b] transition-[transform,background-color] duration-[120ms] ease-out hover:bg-spruce-hover active:translate-y-[1px] active:scale-[0.97] disabled:opacity-50 ${size === 'lg' ? 'h-14 px-6 text-[19px]' : 'h-12 px-5 text-[16px]'} ${className}`}
    >
      {children}
    </button>
  )
}

export function PaperButton({ className = '', size = 'md', children, ...rest }: BtnProps) {
  return (
    <button
      {...rest}
      className={`inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-[6px] border border-paper-edge bg-paper-raised font-display text-ink shadow-[0_2px_0_#cdc2ad] transition-[transform,border-color] duration-[120ms] ease-out hover:border-spruce active:translate-y-[1px] active:scale-[0.97] disabled:opacity-50 ${size === 'lg' ? 'h-14 px-6 text-[19px]' : 'h-12 px-4 text-[16px]'} ${className}`}
    >
      {children}
    </button>
  )
}

/** Round icon button for world-space chrome (settings, records, pause). 48 dp. */
export function IconButton({ label, children, className = '', dark, ...rest }: React.ButtonHTMLAttributes<HTMLButtonElement> & { label: string; dark?: boolean }) {
  return (
    <button
      {...rest}
      aria-label={label}
      title={label}
      className={`grid h-12 w-12 place-items-center rounded-full transition-[transform,background-color] duration-[120ms] ease-out active:scale-[0.94] ${dark ? 'bg-scrim text-paper hover:bg-black/70 ring-1 ring-white/15' : 'bg-paper-raised text-ink ring-1 ring-paper-edge shadow-[0_2px_0_#cdc2ad] hover:ring-spruce'} ${className}`}
    >
      {children}
    </button>
  )
}

export function BackButton({ onClick, label = 'Back', dark }: { onClick: () => void; label?: string; dark?: boolean }) {
  return (
    <button
      onClick={onClick}
      className={`flex h-12 items-center gap-1 rounded-full pl-2 pr-4 font-display text-[16px] transition-[transform,background-color] duration-[120ms] ease-out active:scale-[0.96] ${dark ? 'bg-scrim text-paper ring-1 ring-white/15 hover:bg-black/70' : 'bg-paper-raised text-ink ring-1 ring-paper-edge hover:ring-spruce'}`}
    >
      <ChevronLeft size={22} strokeWidth={2.2} />
      {label}
    </button>
  )
}

/* Chips ----------------------------------------------------------------- */

export type Tone = 'neutral' | 'good' | 'warn' | 'bad' | 'spruce' | 'ink' | 'route'
const TONE: Record<Tone, string> = {
  neutral: 'bg-paper-sunk text-ink-soft',
  good: 'bg-good/15 text-good',
  warn: 'bg-warn/20 text-[#7a5410]',
  bad: 'bg-bad/15 text-bad',
  spruce: 'bg-spruce text-spruce-ink',
  ink: 'bg-ink text-paper',
  route: 'bg-route text-ink',
}

export function Chip({ tone = "neutral", children, className = "" }: { key?: React.Key; tone?: Tone; children: React.ReactNode; className?: string }) {
  return <span className={`inline-flex h-6 items-center gap-1 whitespace-nowrap rounded-full px-2.5 text-[12px] font-medium ${TONE[tone]} ${className}`}>{children}</span>
}

/** Marks prototype-only behaviour so nobody mistakes it for shipped Godot behaviour. */
export function SimTag({ children = 'Simulated', className = '' }: { children?: React.ReactNode; className?: string }) {
  return <span className={`inline-flex h-5 items-center rounded-sm border border-dashed border-ember/70 bg-ember/10 px-1.5 text-[11px] font-semibold text-ember ${className}`}>{children}</span>
}

/** Marks a field that needs persistent data the current saves do not hold. */
export function NewDataTag({ className = '' }: { className?: string }) {
  return <span className={`inline-flex h-5 items-center gap-1 rounded-sm border border-dashed border-[#4a7593] bg-[#4a7593]/10 px-1.5 text-[11px] font-semibold text-[#2f5772] ${className}`}>◇ New data</span>
}

/* Stars ----------------------------------------------------------------- */

export function Stars({ n, of = 3, size = 14, light }: { n: number; of?: number; size?: number; light?: boolean }) {
  return (
    <span className="inline-flex gap-0.5" aria-label={`${n} of ${of} stars`}>
      {Array.from({ length: of }).map((_, i) => (
        <Star key={i} size={size} strokeWidth={1.8} className={i < n ? 'fill-star text-[#b07e1f]' : light ? 'text-paper/40' : 'text-ink-muted/40'} />
      ))}
    </span>
  )
}

/* Meters ---------------------------------------------------------------- */

/** A bar that always pairs colour with a word (repo rule: never colour alone). */
export function Meter({ value, label, word, badHigh, preview = 0, dark, className = "" }: { key?: React.Key; value: number; label: string; word?: string; badHigh?: boolean; preview?: number; dark?: boolean; className?: string }) {
  const bad = badHigh ? value > 55 : value < 35
  const warn = badHigh ? value > 35 : value < 55
  const fill = bad ? 'bg-bad' : warn ? 'bg-warn' : 'bg-stam-high'
  const after = Math.max(0, Math.min(100, value + preview))
  const good = (preview < 0) === !!badHigh
  return (
    <div className={className}>
      <div className={`flex items-baseline justify-between text-[12px] ${dark ? 'text-paper' : 'text-ink-soft'}`}>
        <span className="font-medium">{label}</span>
        <span className="tabular flex items-baseline gap-1">
          {word && <span className={dark ? 'text-paper/70' : 'text-ink-muted'}>{word}</span>}
          <span className="font-semibold">{value}</span>
          {preview !== 0 && <span className={`font-semibold ${good ? 'text-good' : 'text-bad'}`}>{preview > 0 ? '+' : ''}{preview}</span>}
        </span>
      </div>
      <div className={`relative mt-1 h-[6px] overflow-hidden rounded-full ${dark ? 'bg-black/40' : 'bg-ink/10'}`}>
        <motion.div className={`absolute inset-y-0 left-0 rounded-full ${fill}`} animate={{ width: `${value}%` }} transition={{ duration: 0.2, ease: [0.23, 1, 0.32, 1] }} />
        {preview !== 0 && (
          <div className={`absolute inset-y-0 ${good ? 'bg-good' : 'bg-bad'} opacity-80`} style={{ left: `${Math.min(value, after)}%`, width: `${Math.abs(after - value)}%` }} />
        )}
      </div>
    </div>
  )
}

/* Surfaces -------------------------------------------------------------- */

/** The field-journal page: paper, a hairline edge, a slight lift off the world. */
export function JournalPanel({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`paper-grain rounded-[10px] border border-paper-edge shadow-[0_12px_30px_rgb(0_0_0/0.35)] ${className}`}>
      {children}
    </div>
  )
}

export function Kicker({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <div className={`text-[12px] font-medium text-ink-muted ${className}`}>{children}</div>
}
