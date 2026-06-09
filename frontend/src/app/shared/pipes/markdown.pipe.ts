import { Pipe, PipeTransform, inject } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { marked, Renderer } from 'marked';

const renderer = new Renderer();

renderer.table = ({ header, rows }) => {
  const headerHtml = header.map(cell =>
    `<th>${cell.tokens.map(t => ('text' in t ? t.text : '')).join('')}</th>`
  ).join('');

  const bodyHtml = rows.map(row =>
    `<tr>${row.map(cell =>
      `<td>${cell.tokens.map(t => ('text' in t ? t.text : '')).join('')}</td>`
    ).join('')}</tr>`
  ).join('');

  return `<div class="ai-table-wrap"><table><thead><tr>${headerHtml}</tr></thead><tbody>${bodyHtml}</tbody></table></div>`;
};

@Pipe({ name: 'markdown', standalone: true })
export class MarkdownPipe implements PipeTransform {
  private readonly sanitizer = inject(DomSanitizer);

  transform(value: string): SafeHtml {
    const html = marked.parse(value ?? '', { async: false, renderer }) as string;
    return this.sanitizer.bypassSecurityTrustHtml(html);
  }
}
