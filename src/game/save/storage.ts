/** Where saves go. The app uses SQLite; tests use memory. */
export type SaveStorage = {
  read(key: string): Promise<string | null>;
  write(key: string, value: string): Promise<void>;
  remove(key: string): Promise<void>;
};

export function memoryStorage(seed: Record<string, string> = {}): SaveStorage & { data: Record<string, string> } {
  const data: Record<string, string> = { ...seed };
  return {
    data,
    async read(key) {
      return key in data ? data[key] : null;
    },
    async write(key, value) {
      data[key] = value;
    },
    async remove(key) {
      delete data[key];
    },
  };
}
