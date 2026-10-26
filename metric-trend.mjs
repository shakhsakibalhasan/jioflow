// Period-over-period change, never a share of the current total.
export function metricTrend(current,previous){
 if(current===null||current===undefined||previous===null||previous===undefined||!Number.isFinite(Number(current))||!Number.isFinite(Number(previous)))return {tone:'neutral',text:'—'};
 const a=Number(current),b=Number(previous),delta=a-b;
 if(!delta)return {tone:'neutral',text:'0.0%'};
 if(b===0)return {tone:delta>0?'up':'down',text:delta>0?'↑ New':'↓ New'};
 return {tone:delta>0?'up':'down',text:(delta>0?'↑ ':'↓ ')+(Math.abs(delta)/Math.abs(b)*100).toFixed(1)+'%'};
}
export function paintMetricTrend(tile,current,previous){const badge=tile.querySelector('.change-badge');if(!badge)return;const result=metricTrend(current,previous);badge.classList.remove('trend-up','trend-down','trend-neutral');badge.classList.add('trend-'+result.tone);badge.textContent=result.text;badge.setAttribute('aria-label',result.tone==='neutral'&&result.text==='—'?'Previous comparison unavailable':'Change from previous period: '+result.text);}
