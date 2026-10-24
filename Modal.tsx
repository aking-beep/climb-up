import React from 'react'
import { motion } from 'framer-motion'
import { X } from 'lucide-react'
import { useGame } from '../state/GameState'

interface Props {
  kicker?: string
  title: string
  onClose?: () => void
  width?: number
  children: React.ReactNode
  footer?: React.ReactNode
}

/**
 * The one modal: a journal page over a 66% ink scrim. Enters at scale 0.96 +
 * fade (220 ms, strong ease-out), exits mirrored at 160 ms. Back / scrim tap closes.
 */
export function Modal({ kicker, title, onClose, width = 520, children, footer }: Props) {
  const { settings } = useGame()
  const d = settings.reducedMotion ? 0 : 1
  return (
    <motion.div
      className="absolute inset-0 z-40 flex items-center justify-center bg-scrim"
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0, transition: { duration: 0.16 * d } }}
      transition={{ duration: 0.2 * d }}
      onClick={onClose}
    >
      <motion.div
        role="dialog"
        aria-label={title}
        onClick={e => e.stopPropagation()}
        className="paper-grain flex max-h-[372px] flex-col rounded-[12px] border border-paper-edge shadow-[0_20px_50px_rgb(0_0_0/0.5)]"
        style={{ width }}
        initial={{ opacity: 0, scale: 0.96, y: 6 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.98, transition: { duration: 0.16 * d } }}
        transition={{ duration: 0.22 * d, ease: [0.23, 1, 0.32, 1] }}
      >
        <div className="flex items-start justify-between px-5 pt-4">
          <div>
            {kicker && <div className="text-[12px] font-medium text-ink-muted">{kicker}</div>}
            <div className="font-display text-[24px] leading-tight text-ink">{title}</div>
          </div>
          {onClose && (
            <button onClick={onClose} aria-label="Close" className="-mr-2 -mt-1 grid h-12 w-12 place-items-center rounded-full text-ink-muted transition-colors duration-150 hover:bg-paper-sunk hover:text-ink">
              <X size={22} />
            </button>
          )}
        </div>
        <div className="no-scrollbar min-h-0 flex-1 overflow-y-auto px-5 pb-4 pt-2">{children}</div>
        {footer && <div className="flex gap-2 border-t border-paper-edge px-5 py-3">{footer}</div>}
      </motion.div>
    </motion.div>
  )
}
