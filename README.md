# Formatura 2027 · app da dinâmica (PSP)

Aplicação estática (GitHub Pages) + Supabase. Sem bibliotecas externas.

## Arquivos
- `index.html`: tela do aluno (celular). Abre com `?sala=CODIGO`.
- `professor.html`: painel do professor (projetor). Botão por etapa, contador de respostas, revelação, fichas agregadas, ranking, frases, CSV e apagar tudo.
- `shared.js`: textos, lugares, vínculos e etapas (edite aqui para mudar qualquer texto).
- `config.js`: URL e chave pública do Supabase.
- `schema.sql`: tabelas e funções do banco.

## Instalação (10 min)
1. Crie um projeto Supabase **só para esta aula** (ou rode o schema em um projeto de teste). As tabelas levam o prefixo `f27_`.
2. SQL Editor → cole e execute `schema.sql` inteiro.
3. Settings → API: copie a *Project URL* e a chave *anon/publishable* para `config.js`.
4. Suba a pasta num repositório e ative GitHub Pages (branch main, raiz).
5. Na aula: abra `professor.html`, clique em **Criar sala** (código + PIN) e projete a etapa "Entrada da turma", que mostra o endereço para os alunos.

## Privacidade (como foi implementado)
- Tabelas com RLS ligado e sem políticas: a chave pública só chama as funções.
- O professor não tem função que devolva a ficha individual; só agregados.
- A revelação e o CSV saem embaralhados, sem apelido e sem identificador.
- A frase final é gravada sem aluno e sem horário.
- "Apagar todos os dados" remove a sala e tudo ligado a ela.
- Ressalva: quem tem acesso administrativo ao banco (você, no painel do Supabase) pode ligar apelido e escolhas pelas tabelas. O professor, pelo painel do app, não.
