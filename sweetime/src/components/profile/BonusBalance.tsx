import { Sparkles } from 'lucide-react';
import { Card } from '@/components/ui/Card';

export function BonusBalance({ balance }: { balance: number }) {
  return (
    <Card className="bg-gradient-to-br from-pink-200 via-pink-100 to-mint-100">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-berry-600">Бонусный баланс</p>
          <p className="mt-1 font-display text-4xl font-semibold text-berry-600">{balance} ★</p>
          <p className="mt-1 text-xs text-berry-600/70">
            Можно оплатить до 30% следующего заказа
          </p>
        </div>
        <Sparkles className="h-10 w-10 text-berry-500/60" />
      </div>
    </Card>
  );
}
