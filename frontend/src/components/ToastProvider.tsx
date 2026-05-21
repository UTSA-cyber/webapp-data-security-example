import * as Toast from '@radix-ui/react-toast';
import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';

interface ToastMessage {
  id: number;
  title: string;
  description?: string;
  tone: 'info' | 'error';
}

interface ToastContextValue {
  show: (msg: Omit<ToastMessage, 'id'>) => void;
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

let nextId = 0;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [messages, setMessages] = useState<ToastMessage[]>([]);

  const show = useCallback((msg: Omit<ToastMessage, 'id'>) => {
    setMessages((prev) => [...prev, { ...msg, id: ++nextId }]);
  }, []);

  const dismiss = useCallback((id: number) => {
    setMessages((prev) => prev.filter((m) => m.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ show }}>
      <Toast.Provider swipeDirection="right" duration={6000}>
        {children}
        {messages.map((m) => (
          <Toast.Root
            key={m.id}
            onOpenChange={(open) => !open && dismiss(m.id)}
            className={`grid grid-cols-[auto_max-content] items-start gap-x-4 rounded-md border p-4 shadow-lg
              data-[state=open]:animate-in data-[state=closed]:animate-out
              ${m.tone === 'error'
                ? 'border-rose-300 bg-rose-50 text-rose-900'
                : 'border-slate-300 bg-white text-slate-900'}`}
          >
            <div>
              <Toast.Title className="text-sm font-semibold">{m.title}</Toast.Title>
              {m.description && (
                <Toast.Description className="mt-1 text-xs">{m.description}</Toast.Description>
              )}
            </div>
            <Toast.Close className="text-xs text-slate-500 hover:text-slate-900">close</Toast.Close>
          </Toast.Root>
        ))}
        <Toast.Viewport className="fixed bottom-4 right-4 z-50 flex w-96 max-w-[calc(100vw-2rem)] flex-col gap-2" />
      </Toast.Provider>
    </ToastContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within ToastProvider');
  return ctx;
}
