/*
 * Copyright 2026 Davils
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// The stylesheet and script embedded in the HTML report.
///
/// Both are inlined so that the report is one file without external
/// resources; the report allows exactly these two through hashes in its
/// content security policy.
final class HtmlAssets {
  /// Prevents instantiation; this type only offers constants.
  const HtmlAssets._();

  /// The stylesheet after the components of shadcn/ui (MIT License): its
  /// neutral theme in light and dark, cards, badges, tables, inputs,
  /// toggles, tabs, an accordion and the sidebar layout; responsive and
  /// printable.
  static const css = '''
:root{color-scheme:light dark;--radius:.625rem;--background:oklch(1 0 0);--foreground:oklch(.145 0 0);--card:oklch(1 0 0);--card-foreground:oklch(.145 0 0);--primary:oklch(.205 0 0);--primary-foreground:oklch(.985 0 0);--secondary:oklch(.97 0 0);--secondary-foreground:oklch(.205 0 0);--muted:oklch(.97 0 0);--muted-foreground:oklch(.556 0 0);--accent:oklch(.97 0 0);--accent-foreground:oklch(.205 0 0);--destructive:oklch(.577 .245 27.325);--border:oklch(.922 0 0);--input:oklch(.922 0 0);--ring:oklch(.708 0 0);--sidebar:oklch(.985 0 0);--sidebar-foreground:oklch(.145 0 0);--sidebar-accent:oklch(.97 0 0);--sidebar-border:oklch(.922 0 0);--chart-1:oklch(.809 .105 251.813);--chart-2:oklch(.623 .214 259.815);--chart-3:oklch(.546 .245 262.881);--chart-4:oklch(.488 .243 264.376);--chart-5:oklch(.424 .199 265.638);--passed:oklch(.627 .194 149.214);--failed:var(--destructive);--error:oklch(.666 .179 58.318);--skipped:var(--muted-foreground);--critical:oklch(.577 .245 27.325);--high:oklch(.646 .222 41.116);--medium:oklch(.769 .188 70.08);--low:oklch(.623 .214 259.815);--unknown:oklch(.708 0 0);--add:oklch(.962 .044 156.743);--add-foreground:oklch(.448 .119 151.328);--del:oklch(.936 .032 17.717);--del-foreground:oklch(.505 .213 27.518);--shadow-xs:0 1px 2px 0 rgb(0 0 0/.05);--shadow-sm:0 1px 3px 0 rgb(0 0 0/.1),0 1px 2px -1px rgb(0 0 0/.1);--font-sans:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;--font-mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono",monospace}
@media (prefers-color-scheme:dark){:root{--background:oklch(.145 0 0);--foreground:oklch(.985 0 0);--card:oklch(.205 0 0);--card-foreground:oklch(.985 0 0);--primary:oklch(.922 0 0);--primary-foreground:oklch(.205 0 0);--secondary:oklch(.269 0 0);--secondary-foreground:oklch(.985 0 0);--muted:oklch(.269 0 0);--muted-foreground:oklch(.708 0 0);--accent:oklch(.371 0 0);--accent-foreground:oklch(.985 0 0);--destructive:oklch(.704 .191 22.216);--border:oklch(1 0 0/10%);--input:oklch(1 0 0/15%);--ring:oklch(.556 0 0);--sidebar:oklch(.205 0 0);--sidebar-foreground:oklch(.985 0 0);--sidebar-accent:oklch(.269 0 0);--sidebar-border:oklch(1 0 0/10%);--passed:oklch(.723 .219 149.579);--error:oklch(.828 .189 84.429);--critical:oklch(.704 .191 22.216);--high:oklch(.75 .183 55.934);--medium:oklch(.852 .199 91.936);--low:oklch(.707 .165 254.624);--add:oklch(.266 .065 152.934);--add-foreground:oklch(.871 .15 154.449);--del:oklch(.258 .092 26.042);--del-foreground:oklch(.808 .114 19.571)}}
*,*:before,*:after{box-sizing:border-box;border:0 solid var(--border)}
html{-webkit-text-size-adjust:100%;scroll-behavior:smooth;scroll-padding-top:4.5rem}
body{margin:0;background:var(--sidebar);color:var(--foreground);font-family:var(--font-sans);font-size:1rem;line-height:1.5;-webkit-font-smoothing:antialiased}
a{color:inherit;text-decoration:none}
code,pre,.mono{font-family:var(--font-mono)}
h1,h2,h3,h4,p,dl,dd,ul{margin:0}
ul{padding:0;list-style:none}
[hidden]{display:none!important}
.icon{width:1rem;height:1rem;flex:none}
.muted{color:var(--muted-foreground)}
.tabular{font-variant-numeric:tabular-nums}
.sidebar{display:none}
.inset{min-height:100vh;background:var(--background);display:flex;flex-direction:column;min-width:0}
@media (min-width:1024px){.sidebar{display:flex;flex-direction:column;position:fixed;inset:0 auto 0 0;width:16rem;padding:.5rem;color:var(--sidebar-foreground)}.inset{margin:.5rem .5rem .5rem 16rem;min-height:calc(100vh - 1rem);border-radius:calc(var(--radius)*1.4);box-shadow:var(--shadow-sm);overflow:clip}.mobile-nav{display:none!important}}
.sb-header{padding:.5rem}
.sb-brand{display:flex;align-items:center;gap:.5rem;padding:.375rem;border-radius:calc(var(--radius)*.8)}
.sb-brand:hover{background:var(--sidebar-accent)}
.logo{display:flex;align-items:center;justify-content:center;width:2rem;height:2rem;border-radius:var(--radius);background:var(--primary);color:var(--primary-foreground);flex:none}
.logo .icon{width:1.125rem;height:1.125rem}
.brand-text{display:grid;line-height:1.25;min-width:0}
.brand-name{font-size:.875rem;font-weight:600}
.brand-sub{font-size:.75rem;color:var(--muted-foreground);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sb-content{flex:1;overflow:auto;min-height:0}
.sb-group{padding:.5rem}
.sb-label{display:flex;align-items:center;height:2rem;padding:0 .5rem;font-size:.75rem;font-weight:500;color:color-mix(in oklch,var(--sidebar-foreground) 70%,transparent)}
.sb-menu{display:flex;flex-direction:column;gap:.25rem}
.sb-button{display:flex;align-items:center;gap:.5rem;height:2rem;padding:0 .5rem;border-radius:calc(var(--radius)*.8);font-size:.875rem;white-space:nowrap;overflow:hidden}
.sb-button span.sb-text{overflow:hidden;text-overflow:ellipsis}
.sb-button:hover,.sb-button.active{background:var(--sidebar-accent);color:var(--accent-foreground)}
.sb-button.active{font-weight:500}
.sb-badge{margin-left:auto;font-size:.75rem;font-weight:500;color:var(--muted-foreground)}
.sb-footer{padding:.75rem 1rem;font-size:.75rem;color:var(--muted-foreground);line-height:1.6}
.site-header{position:sticky;top:0;z-index:10;display:flex;align-items:center;gap:.5rem;height:3.5rem;padding:0 1rem;border-bottom:1px solid var(--border);background:color-mix(in oklch,var(--background) 92%,transparent);backdrop-filter:blur(8px)}
.sh-title{display:flex;align-items:center;gap:.5rem;min-width:0;flex:1}
.sh-title h1{font-size:1rem;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sep-v{width:1px;height:1rem;background:var(--border);flex:none}
.sh-sub{font-size:.875rem;white-space:nowrap}
@media (max-width:639px){.sh-sub,.sh-title .sep-v{display:none}}
.mobile-nav{margin:1rem 1rem 0;overflow-x:auto;max-width:calc(100% - 2rem)}
.main{display:flex;flex-direction:column;gap:1rem;padding:1rem;flex:1}
@media (min-width:768px){.main{gap:1.5rem;padding:1.5rem}.site-header{padding:0 1.5rem}}
.page-head{display:flex;flex-direction:column;gap:.25rem}
.page-title{font-size:1.5rem;font-weight:600;letter-spacing:-.025em;line-height:1.2}
.page-head p{font-size:.875rem}
.card{display:flex;flex-direction:column;gap:1.5rem;padding:1.5rem 0;border:1px solid var(--border);border-radius:calc(var(--radius)*1.4);background:var(--card);color:var(--card-foreground);box-shadow:var(--shadow-sm);min-width:0}
.card-header{display:grid;grid-auto-rows:min-content;align-items:start;gap:.375rem;padding:0 1.5rem}
.card-header.with-action{grid-template-columns:minmax(0,1fr) auto}
.card-title{font-size:1rem;font-weight:600;line-height:1}
.card-description{font-size:.875rem;color:var(--muted-foreground)}
.card-action{grid-column:2;grid-row:1/span 2;align-self:start;justify-self:end}
.card-content{padding:0 1.5rem;min-width:0}
.card-footer{display:flex;align-items:center;padding:0 1.5rem;font-size:.875rem}
.kpis{display:grid;grid-template-columns:1fr;gap:1rem}
@media (min-width:640px){.kpis{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media (min-width:1280px){.kpis{grid-template-columns:repeat(4,minmax(0,1fr))}}
.kpi{background:linear-gradient(to top,color-mix(in oklch,var(--primary) 5%,var(--card)),var(--card));box-shadow:var(--shadow-xs)}
@media (prefers-color-scheme:dark){.kpi{background:var(--card)}}
.kpi .card-title{font-size:1.875rem;font-weight:600;font-variant-numeric:tabular-nums;line-height:2.25rem;white-space:nowrap}
.kpi .card-footer{flex-direction:column;align-items:flex-start;gap:.375rem;font-size:.875rem}
.kpi .lead{display:flex;align-items:center;gap:.5rem;font-weight:500}
.kpi .lead .icon{order:-1}
.charts{display:grid;grid-template-columns:1fr;gap:1rem}
@media (min-width:1024px){.charts{grid-template-columns:repeat(3,minmax(0,1fr))}}
.badge{display:inline-flex;align-items:center;justify-content:center;gap:.25rem;width:fit-content;flex:none;overflow:hidden;border:1px solid transparent;border-radius:999px;padding:.125rem .5rem;font-size:.75rem;font-weight:500;line-height:1rem;white-space:nowrap}
.badge .icon{width:.75rem;height:.75rem}
.badge-outline{border-color:var(--border);color:var(--foreground)}
.badge-secondary{background:var(--secondary);color:var(--secondary-foreground)}
.badge-destructive{background:var(--destructive);color:#fff}
@media (prefers-color-scheme:dark){.badge-destructive{background:color-mix(in oklch,var(--destructive) 60%,transparent)}}
.st-passed{color:var(--passed)}.st-failed{color:var(--failed)}.st-error{color:var(--error)}.st-skipped{color:var(--skipped)}
.dot{width:.5rem;height:.5rem;border-radius:999px;flex:none;background:var(--unknown)}
.dot.critical{background:var(--critical)}.dot.high{background:var(--high)}.dot.medium{background:var(--medium)}.dot.low{background:var(--low)}.dot.unknown{background:var(--unknown)}
.dot.c1{background:var(--chart-1)}.dot.c3{background:var(--chart-3)}.dot.c5{background:var(--chart-5)}.dot.bl{background:var(--muted)}
.f-critical{fill:var(--critical)}.f-high{fill:var(--high)}.f-medium{fill:var(--medium)}.f-low{fill:var(--low)}.f-unknown{fill:var(--unknown)}
.f-passed{fill:var(--passed)}.f-failed{fill:var(--failed)}.f-primary{fill:var(--primary)}.f-c1{fill:var(--chart-1)}.f-c3{fill:var(--chart-3)}.f-c5{fill:var(--chart-5)}.f-muted{fill:var(--muted)}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:.5rem;flex:none;height:2rem;padding:0 .75rem;border-radius:calc(var(--radius)*.8);font:inherit;font-size:.875rem;font-weight:500;white-space:nowrap;cursor:pointer;transition:background .15s,color .15s,box-shadow .15s;outline:none}
.btn-outline{border:1px solid var(--border);background:var(--background);color:var(--foreground);box-shadow:var(--shadow-xs)}
.btn-outline:hover{background:var(--accent);color:var(--accent-foreground)}
@media (prefers-color-scheme:dark){.btn-outline{border-color:var(--input);background:color-mix(in oklch,var(--input) 30%,transparent)}.btn-outline:hover{background:color-mix(in oklch,var(--input) 50%,transparent)}}
.btn:focus-visible,.input:focus-visible,.select:focus-visible,.toggle:focus-visible,.tab:focus-visible,.acc-trigger:focus-visible,.sb-button:focus-visible,a:focus-visible{outline:none;box-shadow:0 0 0 3px color-mix(in oklch,var(--ring) 50%,transparent);border-color:var(--ring)}
.toolbar{display:flex;flex-wrap:wrap;align-items:center;gap:.5rem;padding:0 1.5rem}
.input-wrap{position:relative;flex:1 1 14rem;min-width:0}
.input-wrap .icon{position:absolute;left:.625rem;top:50%;transform:translateY(-50%);color:var(--muted-foreground);pointer-events:none}
.input{width:100%;height:2.25rem;min-width:0;padding:.25rem .75rem .25rem 2rem;border:1px solid var(--input);border-radius:calc(var(--radius)*.8);background:transparent;color:var(--foreground);font:inherit;font-size:.875rem;box-shadow:var(--shadow-xs);transition:box-shadow .15s,border-color .15s}
.input::placeholder{color:var(--muted-foreground)}
@media (prefers-color-scheme:dark){.input,.select{background:color-mix(in oklch,var(--input) 30%,transparent)}}
.select-wrap{position:relative;flex:none}
.select{appearance:none;-webkit-appearance:none;height:2.25rem;padding:0 2rem 0 .75rem;border:1px solid var(--input);border-radius:calc(var(--radius)*.8);background:transparent;color:var(--foreground);font:inherit;font-size:.875rem;box-shadow:var(--shadow-xs);cursor:pointer}
.select option{background:var(--background);color:var(--foreground)}
.select-wrap .icon{position:absolute;right:.625rem;top:50%;transform:translateY(-50%);opacity:.5;pointer-events:none}
.toggle-group{display:inline-flex;align-items:center;border-radius:calc(var(--radius)*.8);box-shadow:var(--shadow-xs);flex-wrap:wrap}
.toggle{display:inline-flex;align-items:center;gap:.375rem;height:2.25rem;padding:0 .625rem;border:1px solid var(--input);border-left-width:0;background:transparent;color:var(--muted-foreground);font:inherit;font-size:.875rem;font-weight:500;cursor:pointer;transition:background .15s,color .15s}
.toggle:first-child{border-left-width:1px;border-radius:calc(var(--radius)*.8) 0 0 calc(var(--radius)*.8)}
.toggle:last-child{border-radius:0 calc(var(--radius)*.8) calc(var(--radius)*.8) 0}
.toggle:hover{background:var(--muted);color:var(--foreground)}
.toggle[aria-pressed=true]{background:var(--accent);color:var(--accent-foreground)}
.toggle[aria-pressed=false] .dot{opacity:.35}
.toggle .count{color:var(--muted-foreground);font-variant-numeric:tabular-nums}
.table-frame{margin:0 1.5rem;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
.table-container{position:relative;width:100%;overflow-x:auto}
table{width:100%;border-collapse:collapse;caption-side:bottom;font-size:.875rem}
thead{background:var(--muted)}
thead tr{border-bottom:1px solid var(--border)}
tbody tr{border-bottom:1px solid var(--border);transition:background .15s}
tbody tr:last-child{border-bottom:0}
tbody tr:hover{background:color-mix(in oklch,var(--muted) 50%,transparent)}
th{height:2.5rem;padding:0 .5rem;text-align:left;vertical-align:middle;font-weight:500;white-space:nowrap;color:var(--foreground)}
td{padding:.5rem;vertical-align:middle}
th:first-child,td:first-child{padding-left:1rem}
th:last-child,td:last-child{padding-right:1rem}
.num{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}
.cell-title{font-weight:500}
.cell-link{font-weight:500}
.cell-link:hover{text-decoration:underline;text-underline-offset:4px}
.rule{font-family:var(--font-mono);font-size:.75rem;color:var(--muted-foreground);word-break:break-all}
.desc{font-size:.8125rem;color:var(--muted-foreground);margin-top:.125rem;white-space:pre-line;word-break:break-word}
.meta{display:flex;flex-wrap:wrap;gap:.25rem .75rem;margin-top:.375rem;font-size:.75rem;color:var(--muted-foreground)}
.meta b{color:var(--foreground);font-weight:500}
.meta a{display:inline-flex;align-items:center;gap:.25rem;color:var(--foreground);font-weight:500;text-decoration:underline;text-underline-offset:4px}
.meta a .icon{width:.75rem;height:.75rem}
.loc{font-family:var(--font-mono);font-size:.75rem;word-break:break-all}
.summary-cell{color:var(--muted-foreground);min-width:12rem}
.table-footer{display:flex;align-items:center;justify-content:space-between;gap:1rem;padding:0 1.5rem;font-size:.875rem;color:var(--muted-foreground)}
.empty{padding:2.5rem 1rem;text-align:center;font-size:.875rem;color:var(--muted-foreground)}
.hbars{display:flex;flex-direction:column;gap:.75rem}
.hbar{display:grid;grid-template-columns:5.5rem 1fr 2.5rem;align-items:center;gap:.75rem;font-size:.875rem}
.hbar .label{display:flex;align-items:center;gap:.5rem;color:var(--muted-foreground)}
.track{height:.5rem;border-radius:999px;overflow:hidden;background:color-mix(in oklch,var(--primary) 12%,transparent);line-height:0}
.track svg{display:block;width:100%;height:100%}
.track.tall{height:.75rem}
.progress{height:.5rem;border-radius:999px;overflow:hidden;background:color-mix(in oklch,var(--primary) 20%,transparent);line-height:0;min-width:4rem}
.progress svg{display:block;width:100%;height:100%}
.radial{display:flex;justify-content:center}
.radial svg{width:11rem;height:11rem}
.radial .track-ring{stroke:var(--muted)}
.radial .arc.passed{stroke:var(--chart-2)}.radial .arc.failed{stroke:var(--destructive)}
.radial .mark{stroke:var(--foreground)}
.radial .big{fill:var(--foreground);font-size:1.75rem;font-weight:700}
.radial .small{fill:var(--muted-foreground);font-size:.75rem}
.legend{display:flex;flex-wrap:wrap;justify-content:center;gap:.5rem 1rem;font-size:.75rem;color:var(--muted-foreground)}
.legend li{display:flex;align-items:center;gap:.375rem}
.legend b{color:var(--foreground);font-weight:500;font-variant-numeric:tabular-nums}
.stack-rows{display:flex;flex-direction:column;gap:.625rem;margin-top:1rem}
.stack-row{display:grid;grid-template-columns:3.5rem 1fr 3.5rem;gap:.75rem;align-items:center;font-size:.8125rem}
.stack-row .name{font-family:var(--font-mono);font-size:.75rem;color:var(--muted-foreground);overflow:hidden;text-overflow:ellipsis}
.project-rows .stack-row{grid-template-columns:minmax(0,10rem) 1fr 3.5rem}
.project-rows .name{white-space:nowrap}
.cell-sub{display:block;font-size:.75rem;color:var(--muted-foreground)}
.acc-content .accordion{padding:0 1rem;border:1px solid var(--border);border-radius:var(--radius)}
.card-footer.stack{flex-direction:column;align-items:flex-start;gap:.25rem;font-size:.875rem}
.accordion{padding:0 1.5rem}
.acc-item{border-bottom:1px solid var(--border)}
.acc-item:last-child{border-bottom:0}
.acc-trigger{display:flex;align-items:center;gap:.75rem;padding:1rem 0;font-size:.875rem;font-weight:500;cursor:pointer;list-style:none;border-radius:calc(var(--radius)*.8);outline:none}
.acc-trigger::-webkit-details-marker{display:none}
.acc-trigger:hover .acc-title{text-decoration:underline;text-underline-offset:4px}
.acc-title{display:flex;align-items:center;gap:.5rem;white-space:nowrap}
.acc-summary{flex:1;min-width:0;font-weight:400;color:var(--muted-foreground);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.acc-chevron{color:var(--muted-foreground);transition:transform .2s}
.acc-item[open]>.acc-trigger .acc-chevron{transform:rotate(180deg)}
.acc-content{display:flex;flex-direction:column;gap:1rem;padding:0 0 1rem;font-size:.875rem}
@media (max-width:639px){.acc-trigger{flex-wrap:wrap}.acc-summary{flex-basis:100%;order:3;white-space:normal}}
.alert{display:grid;grid-template-columns:1rem 1fr;gap:.125rem .75rem;align-items:start;padding:.75rem 1rem;border:1px solid var(--border);border-radius:var(--radius);background:var(--card);font-size:.875rem}
.alert .icon{transform:translateY(.125rem)}
.alert-title{font-weight:500;letter-spacing:-.01em}
.alert-description{grid-column:2;color:var(--muted-foreground);white-space:pre-line;word-break:break-word}
.alert.destructive{color:var(--destructive)}
.alert.destructive .alert-description{color:color-mix(in oklch,var(--destructive) 90%,transparent)}
.stats{display:grid;grid-template-columns:repeat(auto-fill,minmax(10rem,1fr));gap:.5rem}
.stat{border:1px solid var(--border);border-radius:var(--radius);padding:.5rem .75rem}
.stat dt{font-size:.75rem;color:var(--muted-foreground)}
.stat dd{font-weight:600;font-variant-numeric:tabular-nums;word-break:break-word}
.sub-heading{font-size:.875rem;font-weight:600;margin-top:.25rem}
.inner-table{border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
.cov-bar{display:flex;align-items:center;gap:.5rem;min-width:9rem}
.cov-bar .progress{flex:1}
.cov-bar span{width:3.25rem;text-align:right;font-variant-numeric:tabular-nums}
.files{display:flex;flex-wrap:wrap;gap:.375rem}
.files li{font-family:var(--font-mono);font-size:.75rem;padding:.125rem .5rem;border-radius:calc(var(--radius)*.6);background:var(--muted)}
.code-block{margin:0;padding:.75rem 0;border:1px solid var(--border);border-radius:var(--radius);background:var(--muted);overflow-x:auto;font-size:.75rem;line-height:1.6}
.code-block span{display:block;padding:0 1rem;white-space:pre}
.code-block .add{background:var(--add);color:var(--add-foreground)}
.code-block .del{background:var(--del);color:var(--del-foreground)}
.code-block .hunk{color:var(--chart-3)}
.tabs{display:flex;flex-direction:column;gap:.75rem}
.tabs-list{display:inline-flex;align-items:center;width:fit-content;height:2.25rem;padding:3px;border-radius:var(--radius);background:var(--muted);color:var(--muted-foreground)}
.tab{display:inline-flex;align-items:center;justify-content:center;gap:.375rem;height:100%;padding:.25rem .625rem;border:1px solid transparent;border-radius:calc(var(--radius)*.8);background:transparent;color:color-mix(in oklch,var(--foreground) 60%,transparent);font:inherit;font-size:.875rem;font-weight:500;white-space:nowrap;cursor:pointer;transition:all .15s}
.tab:hover{color:var(--foreground)}
.tab[aria-selected=true]{background:var(--background);color:var(--foreground);box-shadow:var(--shadow-sm)}
@media (prefers-color-scheme:dark){.tab[aria-selected=true]{background:color-mix(in oklch,var(--input) 30%,transparent);border-color:var(--input)}}
.js .tab-heading{display:none}
.site-footer{padding:1rem 1.5rem 1.5rem;font-size:.75rem;color:var(--muted-foreground);text-align:center}
@media (max-width:767px){
#findings thead{display:none}
#findings tbody tr{display:grid;grid-template-columns:auto 1fr;gap:.25rem .75rem;padding:.75rem 1rem}
#findings td{padding:0}
#findings td.c-section{order:1;text-align:right;font-size:.75rem;color:var(--muted-foreground)}
#findings td.c-finding{order:2;grid-column:1/-1}
#findings td.c-loc{order:3;grid-column:1/-1}
.summary-cell,#evaluations th:nth-child(3){display:none}
.kpi .card-title{font-size:1.5rem}}
@media print{body{background:#fff}.sidebar,.mobile-nav,.toolbar,.btn,.tabs-list{display:none!important}.inset{margin:0;box-shadow:none}.site-header{position:static}.card{box-shadow:none;break-inside:avoid}.js .tab-heading{display:block}.tab-panel{display:block!important}}
@media (prefers-reduced-motion:reduce){*{transition:none!important;scroll-behavior:auto!important}}
''';

  /// The script: severity, section and text filters for the finding
  /// explorer, tabs, the current entry of the sidebar, opening linked
  /// sections and projects with the items around them and expanding
  /// everything for printing.
  ///
  /// The report is complete without it; the controls it needs stay hidden
  /// while scripts are disabled.
  static const script = '''
(function () {
  "use strict";
  var root = document.documentElement;
  root.className += " js";
  function all(selector, scope) {
    return Array.prototype.slice.call((scope || document).querySelectorAll(selector));
  }
  var rows = all("#findings tbody tr[data-sev]");
  var controls = document.getElementById("controls");
  var shown = document.getElementById("shown");
  var empty = document.getElementById("no-match");
  var search = document.getElementById("search");
  var section = document.getElementById("section");
  var toggles = controls ? all(".toggle[data-sev]", controls) : [];
  var active = {};
  function apply() {
    var text = search ? search.value.trim().toLowerCase() : "";
    var only = section ? section.value : "";
    var count = 0;
    rows.forEach(function (row) {
      var visible = active[row.getAttribute("data-sev")] !== false &&
        (only === "" || row.getAttribute("data-section") === only) &&
        (text === "" || row.getAttribute("data-text").indexOf(text) !== -1);
      row.hidden = !visible;
      if (visible) { count += 1; }
    });
    if (shown) { shown.textContent = String(count); }
    if (empty) { empty.hidden = count !== 0 || rows.length === 0; }
  }
  function reset() {
    toggles.forEach(function (toggle) {
      toggle.setAttribute("aria-pressed", "true");
      active[toggle.getAttribute("data-sev")] = true;
    });
    if (search) { search.value = ""; }
  }
  if (controls && rows.length > 0) {
    controls.hidden = false;
    toggles.forEach(function (toggle) {
      active[toggle.getAttribute("data-sev")] = true;
      toggle.addEventListener("click", function () {
        var on = toggle.getAttribute("aria-pressed") !== "true";
        toggle.setAttribute("aria-pressed", on ? "true" : "false");
        active[toggle.getAttribute("data-sev")] = on;
        apply();
      });
    });
    if (search) { search.addEventListener("input", apply); }
    if (section) { section.addEventListener("change", apply); }
  }
  all("a[data-section]").forEach(function (link) {
    link.addEventListener("click", function () {
      reset();
      if (section) { section.value = link.getAttribute("data-section"); }
      apply();
    });
  });
  all("[data-tabs]").forEach(function (tabs) {
    var list = tabs.querySelector(".tabs-list");
    var buttons = all(".tab", tabs);
    var panels = all(".tab-panel", tabs);
    function select(index) {
      buttons.forEach(function (button, i) { button.setAttribute("aria-selected", i === index ? "true" : "false"); });
      panels.forEach(function (panel, i) { panel.hidden = i !== index; });
    }
    if (list) { list.hidden = false; }
    buttons.forEach(function (button, i) { button.addEventListener("click", function () { select(i); }); });
    select(0);
  });
  function openTarget() {
    var id = decodeURIComponent(location.hash.slice(1));
    var node = id ? document.getElementById(id) : null;
    while (node) {
      if (node.tagName === "DETAILS") { node.open = true; }
      node = node.parentElement;
    }
  }
  window.addEventListener("hashchange", openTarget);
  openTarget();
  var links = all(".sb-button[href^='#']");
  if ("IntersectionObserver" in window && links.length > 0) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) { return; }
        links.forEach(function (link) {
          link.classList.toggle("active", link.getAttribute("href") === "#" + entry.target.id);
        });
      });
    }, { rootMargin: "-20% 0px -70% 0px" });
    links.forEach(function (link) {
      var target = document.getElementById(link.getAttribute("href").slice(1));
      if (target) { observer.observe(target); }
    });
  }
  window.addEventListener("beforeprint", function () {
    all("details").forEach(function (panel) { panel.open = true; });
    rows.forEach(function (row) { row.hidden = false; });
  });
})();
''';
}
