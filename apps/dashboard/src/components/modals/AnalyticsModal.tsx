import { ModalOverlay } from './ModalOverlay';

interface AnalyticsModalProps {
  onClose: () => void;
}

export function AnalyticsModal({ onClose }: AnalyticsModalProps) {
  return (
    <ModalOverlay title="Sensor Analytics" onClose={onClose} width="max-w-5xl">
      <div className="flex flex-col items-center justify-center py-16 text-base-light">
        <p className="font-light tracking-wider">Historical analytics charts coming soon...</p>
      </div>
    </ModalOverlay>
  );
}
