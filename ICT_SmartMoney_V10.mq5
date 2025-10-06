//+------------------------------------------------------------------+
//|                                                ICT_SmartMoney_V10.mq5 |
//| Advanced ICT‑style Expert Advisor for Volatility 10            |
//+------------------------------------------------------------------+
#property copyright "ChatGPT"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

// === Inputs / Parameters ===
input double LotSize = 0.1;
input int MaxTradesPerDay = 3;
input double StopLossPoints = 20;   // SL (in points) — adjust to your symbol scale
input double TakeProfitPoints = 40; // TP (in points)
input int LookbackBars = 200;       // how many bars back to detect zones
input double MinFVGSize = 5.0;      // minimal gap size (points)
input int OB_Lookback = 5;          // window for order block detection
input double OTE_LowPct = 0.62;     // lower bound of OTE zone
input double OTE_HighPct = 0.79;    // upper bound of OTE zone

// === Internal Variables ===
int tradesToday = 0;
datetime lastTradeDay = 0;

struct Zone {
   double top;
   double bottom;
   datetime time;
   bool isBullish;  // true = bullish block, false = bearish
};

Zone orderBlocks[];
Zone fvgZones[];

//+------------------------------------------------------------------+
//| Expert initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(orderBlocks, 0);
   ArrayResize(fvgZones, 0);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps (FVG)                                    |
//+------------------------------------------------------------------+
void DetectFVGs()
{
   int limit = Bars - LookbackBars;
   for (int i = 2; i < limit; i++)
   {
      double high1 = High[i+2];
      double low3 = Low[i];
      // bullish FVG (gap above)
      if (low3 > high1)
      {
         double gap = low3 - high1;
         if (gap >= MinFVGSize)
         {
            Zone z;
            z.bottom = high1;
            z.top = low3;
            z.time = Time[i];
            z.isBullish = true;
            ArrayInsert(fvgZones, 0, z);
         }
      }
      // bearish FVG (gap below)
      }
}

//+------------------------------------------------------------------+
//| Check if price is inside a zone                                  |
//+------------------------------------------------------------------+
bool PriceInsideZone(Zone &z)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (bid >= z.bottom && bid <= z.top);
}

//+------------------------------------------------------------------+
//| Compute OTE (Optimal Trade Entry)                                |
//+------------------------------------------------------------------+
bool ComputeOTE(double &otePrice, bool bullishSetup)
{
   int idxHigh = iHighest(NULL, 0, MODE_HIGH, LookbackBars, 1);
   int idxLow  = iLowest(NULL, 0, MODE_LOW, LookbackBars, 1);
   double hi = High[idxHigh];
   double lo = Low[idxLow];
   if (bullishSetup)
   {
      double diff = hi - lo;
      double oteLow = lo + diff * (1.0 - OTE_HighPct);
      double oteHigh = lo + diff * (1.0 - OTE_LowPct);
      otePrice = (oteLow + oteHigh) / 2.0;
   }
   else
   {
      double diff = hi - lo;
      double oteLow = hi - diff * (1.0 - OTE_HighPct);
      double oteHigh = hi - diff * (1.0 - OTE_LowPct);
      otePrice = (oteLow + oteHigh) / 2.0;
   
   return true;
}
double low1 = Low[i+2];
      double high3 = High[i];
      if (high3 < low1)
      {
         double gap2 = low1 - high3;
         if (gap2 >= MinFVGSize)
         {
            Zone z;
            z.top = high3;
            z.bottom = low1;
            z.time = Time[i];
            z.isBullish = false;
            ArrayInsert(fvgZones, 0, z);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Order Blocks (simplified)                                |
//+------------------------------------------------------------------+
void DetectOrderBlocks()
{
   int limit = Bars - OB_Lookback;
   for (int i = 1; i < limit; i++)
   {
      // bullish block: down candle then reversal up
      if (Close[i+1] < Open[i+1] && Close[i] > Open[i])
      {
         Zone z;
         z.top = High[i+1];
         z.bottom = Low[i+1];
         z.time = Time[i+1];
         z.isBullish = true;
         ArrayInsert(orderBlocks, 0, z);
      }
      // bearish block: up candle then reversal down
      if (Close[i+1] > Open[i+1] && Close[i] < Open[i])
      {
         Zone z2;
         z2.top = High[i+1];
         z2.bottom = Low[i+1];
         z2.time = Time[i+1];
         z2.isBullish = false;
         ArrayInsert(orderBlocks, 0, z2);
      }
      double sl = bid - StopLossPoints * _Point;
            double tp = bid + TakeProfitPoints * _Point;
            if (trade.Buy(LotSize, _Symbol, bid, sl, tp))
            {
               tradesToday++;
               Print("Long Entry at ", bid, " TP: ", tp, " SL: ", sl);
            }
            return;
         }
         if (!bullishSetup && bid >= ote - 5 * _Point)
         {
            double sl = bid + StopLossPoints * _Point;
            double tp = bid - TakeProfitPoints * _Point;
            if (trade.Sell(LotSize, _Symbol, bid, sl, tp))
            {
               tradesToday++;
               Print("Short Entry at ", bid, " TP: ", tp, " SL: ", sl);
            }
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect stop hunt / liquidity sweep                                 |
//+------------------------------------------------------------------+
bool DetectStopHunt(bool &isLongSweep, double &sweepPrice)
{
   int idx = 1;
   double prevHigh = High[idx + 1];
   double curHigh = High[idx];
   double closeCur = Close[idx];
   if (curHigh > prevHigh && closeCur < prevHigh)
   {
      isLongSweep = true;
      sweepPrice = curHigh;
      return true;
   }
   //+------------------------------------------------------------------+
//| Reset daily trade counter                                        |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if (today != lastTradeDay)
   {
      tradesToday = 0;
      lastTradeDay = today;
   }
}

//+------------------------------------------------------------------+
//| Entry logic combining sweep + zones + OTE                         |
//+------------------------------------------------------------------+
void TryEntry()
{
   if (PositionsTotal() > 0)
      return;

   CheckDailyReset();
   if (tradesToday >= MaxTradesPerDay)
      return;

   DetectFVGs();
   DetectOrderBlocks();

   bool isLongSweep = false;
   double sweepPrice = 0.0;
   if (!DetectStopHunt(isLongSweep, sweepPrice))
      return;

   double ote;
   bool bullishSetup = !isLongSweep;
   ComputeOTE(ote, bullishSetup);

   for (int i = 0; i < ArraySize(orderBlocks); i++)
   {
      Zone &z = orderBlocks[i];
      if (z.isBullish == bullishSetup && PriceInsideZone(z))
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if (bullishSetup && bid <= ote + 5 * _Point)
         {
         double prevLow = Low[idx + 1];
   double curLow = Low[idx];
   double closeLow = Close[idx];
   if (curLow < prevLow && closeLow > prevLow)
   {
      isLongSweep = false;
      sweepPrice = curLow;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| OnTick: main loop                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   TryEntry();
}

//+------------------------------------------------------------------+
//| Deinit: cleanup                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
