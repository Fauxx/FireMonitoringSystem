import { ModalOverlay } from './ModalOverlay';

interface ExportModalProps {
  onClose: () => void;
}

export function ExportModal({ onClose }: ExportModalProps) {
  return (
    <ModalOverlay title="Export Data" onClose={onClose} width="max-w-2xl">
      <div className="flex flex-col items-center justify-center py-16 text-base-light">
        <p className="font-light tracking-wider">Data export tool coming soon...</p>
      </div>
    </ModalOverlay>
  );
}
