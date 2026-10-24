import React from 'react'

/**
 * Keeps a crash in one screen from blanking the whole prototype.
 * The rail below stays usable, and the reviewer can jump back to the hub.
 */
type Props = { resetKey: string; onReset: () => void; children: React.ReactNode }
type State = { error: Error | null }

export class ScreenBoundary extends React.Component<Props, State> {
  declare props: Props
  declare setState: (s: State) => void
  state: State = { error: null }

  static getDerivedStateFromError(error: Error) {
    return { error }
  }

  componentDidCatch(error: Error) {
    console.error('Prototype screen crashed:', error)
  }

  componentDidUpdate(prev: { resetKey: string }) {
    if (prev.resetKey !== this.props.resetKey && this.state.error) this.setState({ error: null })
  }

  render() {
    if (!this.state.error) return this.props.children
    return (
      <div className="absolute inset-0 flex items-center justify-center bg-night p-8">
        <div className="paper-grain w-[440px] rounded-[10px] border border-paper-edge p-5 text-ink">
          <h2 className="font-display text-[20px] leading-tight">This screen hit a snag</h2>
          <p className="mt-1.5 text-[13px] leading-snug text-ink-soft">
            The rest of the prototype still works. Pick another place in the bar below, or go back to the hub.
          </p>
          <p className="mt-3 truncate rounded-md bg-paper-sunk px-2 py-1.5 font-mono text-[11px] text-ink-muted">
            {this.state.error.message}
          </p>
          <div className="mt-4 flex gap-2">
            <button
              onClick={() => { this.setState({ error: null }); this.props.onReset() }}
              className="h-9 rounded-md bg-spruce px-4 text-[13px] font-semibold text-spruce-ink transition-colors duration-150 hover:bg-spruce-hover">
              Back to hub
            </button>
            <button
              onClick={() => this.setState({ error: null })}
              className="h-9 rounded-md bg-paper-sunk px-4 text-[13px] font-medium text-ink transition-colors duration-150 hover:bg-paper-edge">
              Try again
            </button>
          </div>
        </div>
      </div>
    )
  }
}
