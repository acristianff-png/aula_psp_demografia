/* Formatura 2027 · dados da dinâmica e acesso ao Supabase (sem bibliotecas externas) */
(function () {
  const C = window.F27_CONFIG || {};
  async function rpc(fn, args) {
    const r = await fetch(C.SUPABASE_URL.replace(/\/$/, "") + "/rest/v1/rpc/" + fn, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: C.SUPABASE_KEY, Authorization: "Bearer " + C.SUPABASE_KEY },
      body: JSON.stringify(args || {})
    });
    const txt = await r.text();
    let j = null; try { j = txt ? JSON.parse(txt) : null; } catch (e) { j = txt; }
    if (!r.ok) throw new Error((j && (j.message || j.hint)) || ("Erro " + r.status));
    return j;
  }
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} },
    del(k) { try { localStorage.removeItem(k); } catch (e) {} },
    sget(k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
    sset(k, v) { try { sessionStorage.setItem(k, v); } catch (e) {} },
    sdel(k) { try { sessionStorage.removeItem(k); } catch (e) {} }
  };

  /* ---- lugares (nome-âncora, descrição na escolha 1, dado do vídeo só na escolha 2) ---- */
  const PLACES = [
    { name: "Distrito Federal", tag: "capital", desc: "Capital de estado. Muitos serviços, hospitais, mercado privado forte, oferta de residência e especializações, mobilidade fácil.", dado: "Hiperconcentração: 5,53 médicos por mil (DF); capitais 6,28 por mil em 2022.", priority: false },
    { name: "Campinas", tag: "grande cidade, não capital · mais de 500 mil hab.", desc: "Grande centro urbano fora da capital. Rede ampla, muitos especialistas, serviços privados e públicos, vida urbana.", dado: "5,31 médicos por mil nas cidades com mais de 500 mil habitantes. Só 49 dos 5.570 municípios têm essa população.", priority: false },
    { name: "Interior", tag: "cidade média", desc: "Cidade de porte médio no interior. Hospital regional, algum mercado privado, menos especialistas, distância da capital.", dado: "Média de 2,31 médicos por mil nos municípios do interior.", priority: true },
    { name: "Serra da Saudade", tag: "pequeno município · até 10 mil hab.", desc: "Município pequeno, sem hospital de maior porte, equipe de saúde enxuta, médico como figura central da comunidade, longe de centros maiores.", dado: "0,43 a 0,45 médico por mil nos municípios de até 10 mil habitantes. Cerca de 44% dos municípios brasileiros.", priority: true },
    { name: "Pará", tag: "deserto médico · área vulnerável ou remota", desc: "Zona rural, distrito indígena, ribeirinha, ou periferia de grande centro com alta vulnerabilidade. Poucos serviços, acesso difícil, necessidade alta.", dado: "O Pará tem 1,18 médico por mil; Norte e Nordeste abaixo da média nacional. Programas oferecem adicional para rural/remoto e distritos indígenas.", priority: true }
  ];
  const V = { PJ: "PJ / plantão", CLT: "CLT privado ou filantrópico", PUB: "Concurso / emprego público", RES: "Residência médica", MM: "Mais Médicos (bolsa-formação)", MPB: "Médicos pelo Brasil", SO: "Serviço obrigatório (2 anos)" };
  const FORA = "Caminho fora da regra";

  const ROUNDS = {
    1: { title: "Rodada 1 · Mercado livre", places: PLACES.map(p => p.name), vincs: [V.PJ, V.CLT, V.PUB, V.RES], only: null,
      video: "Vídeo 1 · Demografia médica (≈13 min)",
      videoMsg: "Prestem atenção em quem são os médicos e onde estão. Depois vocês escolhem de novo.",
      card: "Não há nenhuma política de provimento. Você está formado, tem CRM e pode trabalhar onde e como quiser.\n\nOnde você estaria no primeiro ano?",
      reasons: ["Dado do vídeo", "Reflexão sobre o que eu valorizo", "Nada específico"] },
    2: { title: "Rodada 2 · Mais Médicos e Médicos pelo Brasil", places: PLACES.map(p => p.name), vincs: [V.PJ, V.CLT, V.PUB, V.RES, V.MM, V.MPB],
      only: { [V.MM]: ["Interior", "Serra da Saudade", "Pará"], [V.MPB]: ["Interior", "Serra da Saudade", "Pará"] },
      video: "Vídeos 2 e 3 · Mais Médicos (≈10 min) e Médicos pelo Brasil (≈5 min)",
      videoMsg: "Agora vocês vão ver os números reais: carga horária, bolsa, carreira, incentivos. Depois decidem de novo.",
      card: "Agora existem dois programas federais, além do mercado:\n\n• MAIS MÉDICOS: bolsa-formação, duração de alguns anos prorrogável; integra trabalho e formação (especialização e mestrado profissional); apoio de tutoria; incentivos adicionais conforme a vulnerabilidade do local. Para áreas prioritárias.\n\n• MÉDICOS PELO BRASIL: vínculo inicial de bolsa durante a especialização em MFC; depois, se aprovado na prova de título, carreira com CLT, progressão e gratificação. Para áreas prioritárias.\n\n• MERCADO: como antes.\n\nOs dois programas só existem em cidade média, pequeno município ou área vulnerável.",
      reasons: ["Bolsa / remuneração", "Carga horária", "Carreira e estabilidade", "Formação / especialização", "FIES", "Licença-maternidade", "Local", "Nada específico"] },
    3: { title: "Rodada 3 · Serviço obrigatório", places: ["Interior", "Serra da Saudade", "Pará"], vincs: [V.SO], only: null, fora: true,
      video: "Vídeo 4 · Estratégias internacionais de provimento (≈4 min)",
      videoMsg: "Este vídeo traz o que outros países fizeram. Atenção ao que a OMS recomenda e onde entra o serviço obrigatório.",
      card: "Hipótese de nova regra: TODOS OS FORMADOS cumprem 2 ANOS de serviço remunerado no SUS, em área definida como prioritária pelo governo, antes de iniciar a residência ou de exercer de forma independente.\n\nDepois dos 2 anos, o médico decide livremente.",
      reasons: ["A OMS recomenda", "Outros países fazem", "Evidência de resultado", "Custo pessoal", "Família", "Justiça entre quem estuda onde", "Nada específico"],
      depois: ["Voltar ao plano original", "Ficar onde estava", "Outro caminho"] }
  };

  const ABERTURA = ["A) Sim, faltam médicos", "B) Não, o problema é distribuição", "C) Depende do lugar e do tipo de médico", "D) Outra resposta"];
  const DESAFIOS = ["Vínculos e remuneração (PJ, plantão, desvalorização)", "Carga de trabalho e saúde mental", "Gênero (remuneração, especialidades, feminização)", "Formação (vagas, residência que não acompanha)", "Distribuição e fixação de médicos", "Tecnologias (telessaúde, IA)"];
  const AREAS = ["Clínica médica", "Cirurgia geral", "Pediatria", "Ginecologia e obstetrícia", "Medicina de família e comunidade", "Psiquiatria", "Medicina de emergência", "Outra especialidade clínica", "Outra especialidade cirúrgica", "Diagnóstico (imagem, patologia)", "Saúde coletiva / gestão", "Ainda não sei"];
  const PESA = ["Só eu", "Parceiro(a)", "Filhos", "Pais ou familiares", "Amigos", "Cidade de origem"];
  const VALORIZA = ["Renda", "Estabilidade", "Autonomia", "Impacto social", "Aprendizado", "Prestígio"];

  /* ---- etapas (mesma ordem do schema.sql) ---- */
  const STAGES = [
    ["lobby", "Entrada da turma", "Abertura"], ["ficha", "Criação da ficha", "Abertura"], ["vote0", "Voto de abertura: faltam médicos?", "Abertura"],
    ["r1_card", "R1 · Cartão da regra", "Rodada 1"], ["r1_c1", "R1 · Escolha 1", "Rodada 1"], ["r1_video", "R1 · Vídeo 1", "Rodada 1"], ["r1_c2", "R1 · Escolha 2", "Rodada 1"], ["r1_rev", "R1 · Revelação", "Rodada 1"],
    ["r2_card", "R2 · Cartão da regra", "Rodada 2"], ["r2_c1", "R2 · Escolha 1", "Rodada 2"], ["r2_video", "R2 · Vídeos 2 e 3", "Rodada 2"], ["r2_c2", "R2 · Escolha 2", "Rodada 2"], ["r2_rev", "R2 · Revelação", "Rodada 2"],
    ["r3_card", "R3 · Cartão da regra", "Rodada 3"], ["r3_c1", "R3 · Escolha 1", "Rodada 3"], ["r3_video", "R3 · Vídeo 4", "Rodada 3"], ["r3_c2", "R3 · Escolha 2", "Rodada 3"], ["r3_rev", "R3 · Revelação", "Rodada 3"],
    ["fin_guia", "Pergunta-guia", "Discussão final"], ["fin_fichas", "Mapa das fichas", "Discussão final"], ["fin_plen", "Plenário", "Discussão final"], ["fin_prio", "Priorização dos desafios", "Discussão final"], ["fin_sintese", "Síntese do professor", "Discussão final"],
    ["fec_vote", "Voto final: faltam médicos?", "Fechamento"], ["fec_frase", "Frase anônima", "Fechamento"], ["fec_end", "Encerramento", "Fechamento"]
  ].map(([id, label, group]) => ({ id, label, group }));

  const esc = s => String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const placeByName = n => PLACES.find(p => p.name === n);

  window.F27 = { rpc, store, PLACES, V, FORA, ROUNDS, ABERTURA, DESAFIOS, AREAS, PESA, VALORIZA, STAGES, esc, placeByName };
})();
