import { Clock, Play, StopCircle } from 'lucide-react';
import { useCountdown, formatTimeRemaining } from '@/hooks/useCountdown';

interface CountdownDisplayProps {
    status: string;
    startDatetime?: string | null;
    endDatetime?: string | null;
}

export default function CountdownDisplay({ status, startDatetime, endDatetime }: CountdownDisplayProps) {
    const startCountdown = useCountdown(status === 'SCHEDULED' ? startDatetime : null);
    const endCountdown = useCountdown(status === 'OPEN' ? endDatetime : null);

    if (status === 'SCHEDULED' && startDatetime) {
        const timeStr = formatTimeRemaining(startCountdown);
        if (timeStr === 'Ended') return null;
        
        return (
            <div className="w-full flex items-center space-x-2 px-3 py-2 bg-amber-50 border border-amber-200 rounded-lg text-amber-700">
                <Play className="w-4 h-4 flex-shrink-0" />
                <span className="text-sm font-medium">Starts in: {timeStr}</span>
            </div>
        );
    }

    if (status === 'OPEN' && endDatetime) {
        const timeStr = formatTimeRemaining(endCountdown);
        const isUrgent = endCountdown && endCountdown.total < 3600000; // less than 1 hour
        
        return (
            <div className={`w-full flex items-center space-x-2 px-3 py-2 border rounded-lg ${
                isUrgent 
                    ? 'bg-red-50 border-red-200 text-red-700 animate-pulse' 
                    : 'bg-emerald-50 border-emerald-200 text-emerald-700'
            }`}>
                <StopCircle className="w-4 h-4 flex-shrink-0" />
                <span className="text-sm font-medium">
                    {timeStr === 'Ended' ? 'Ending soon' : `Closes in: ${timeStr}`}
                </span>
            </div>
        );
    }

    return null;
}
