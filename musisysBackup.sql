-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Dec 19, 2023 at 12:42 AM
-- Server version: 10.4.28-MariaDB
-- PHP Version: 8.0.28

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `musisys`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `Ainda_nao_entrevistados_por` (IN `nomeJornalista` VARCHAR(120))   BEGIN
DECLARE ultimaEdicao INTEGER;

    SELECT MAX(numero) INTO ultimaEdicao FROM musisys.edicao;

    SELECT Participante.nome AS NomeArtista
    FROM Participante
    JOIN Contrata ON Contrata.Participante_codigo_ = Participante.codigo
    WHERE Participante.codigo NOT IN (
        SELECT Entrevista.Participante_codigo_
        FROM Entrevista
        JOIN Jornalista ON Jornalista.num_carteira_profissional = Entrevista.Jornalista_num_carteira_profissional_
        WHERE Contrata.Edicao_numero_ = ultimaEdicao AND Jornalista.nome = nomeJornalista
    ) AND Contrata.Edicao_numero_ = ultimaEdicao;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `cartaz` (IN `id` INT)   BEGIN 
SELECT Participante.nome AS NomeParticipante, contrata.Dia_festival_data AS DiaAtuacao
FROM contrata
JOIN Participante ON contrata.Participante_codigo_ = Participante.codigo
WHERE contrata.Edicao_numero_ = id
ORDER BY contrata.Dia_festival_data, contrata.Cachet DESC;


END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `clonarEdicao` (IN `id` INT, IN `dataInicio` DATE)   BEGIN
    DECLARE newId INT;
    DECLARE dataInicioAntigo DATE;

	-- Guarda a data incial da edicao a ser copiada, usado para os dia_festival
    SELECT data_inicio INTO dataInicioAntigo
    FROM Edicao
    WHERE Edicao.numero = id;

	-- Cria o novo numero da edicao, usado por todas as tabelas
    SET newId = novoId();

    -- Insert para a Tabela da Edicao
    INSERT INTO Edicao (numero, nome, localidade, local, data_inicio, data_fim, lotacao)
    SELECT
        newId,
        nome,
        localidade,
        local,
        dataInicio,
        DATE_ADD(dataInicio, INTERVAL DATEDIFF(data_fim, data_inicio) DAY) as data_fim,
        lotacao
    FROM Edicao
    WHERE Edicao.numero = id;

    -- Insert na tabela do palco 
    INSERT INTO Palco (Edicao_numero, codigo, nome)
    SELECT newId, codigo, nome
    FROM Palco
    WHERE Palco.Edicao_numero = id;

    -- Insert na tabela Dia_Festival com informacoes relativas aos dias do evento a ser copiado 
    INSERT INTO Dia_festival (Edicao_numero, data, qtd_espetadores)
    SELECT
        newId,
        DATE_ADD(dataInicio, INTERVAL DATEDIFF(data, dataInicioAntigo) DAY) as new_data,
        qtd_espetadores
    FROM Dia_festival
    WHERE Dia_festival.Edicao_numero = id
    ORDER BY data;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `criarEdicaoPalco` (IN `nomeEdicao` VARCHAR(120), IN `localidadeEdicao` VARCHAR(120), IN `localEdicao` VARCHAR(120), IN `dataInicioEdicao` DATE, IN `dataFimEdicao` DATE, IN `lotacaoEdicao` INT, IN `nomePalco` VARCHAR(120))   BEGIN
DECLARE novoId INT;
DECLARE novoIdPalco INT;

SET novoId = novoId();

INSERT INTO Edicao (numero, nome, localidade, local, data_inicio, data_fim, lotacao)
    VALUES (novoId ,nomeEdicao, localidadeEdicao, localEdicao, dataInicioEdicao, dataFimEdicao, lotacaoEdicao);
    
        INSERT INTO Palco (Edicao_numero, codigo, nome)
    SELECT novoId, (SELECT MAX(codigo) FROM Palco) + 1, nomePalco;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Entrevistados_por` (IN `idEdicao` INT, IN `nomeJornalista` VARCHAR(120))   BEGIN
    SELECT Participante.nome AS NomeArtista
    FROM Participante
    JOIN Contrata ON Contrata.Participante_codigo_ = Participante.codigo
    JOIN Entrevista ON Entrevista.Participante_codigo_ = Contrata.Participante_codigo_
    JOIN Jornalista ON Jornalista.num_carteira_profissional = Entrevista.Jornalista_num_carteira_profissional_
    WHERE Contrata.Edicao_numero_ = idEdicao AND Jornalista.nome = nomeJornalista;
END$$

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `calcularMedia` () RETURNS INT(11)  BEGIN
    DECLARE totalEdicoes INT;
    DECLARE lucroTotal INT;
    DECLARE lucroMedio INT;

    -- Criar tabela temporária para armazenar os resultados
    CREATE TEMPORARY TABLE TempLucros (numero INT, lucro INT);

    SELECT COUNT(numero) INTO totalEdicoes
    FROM Edicao;

    SET lucroTotal = 0;

    INSERT INTO TempLucros (numero, lucro)
    SELECT numero, lucroEdicao(numero) AS lucro
    FROM edicao;

    SELECT SUM(lucro) INTO lucroTotal
    FROM TempLucros;

    SET lucroMedio = lucroTotal / totalEdicoes;

    DROP TEMPORARY TABLE IF EXISTS TempLucros;

    RETURN lucroMedio;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `lucroEdicao` (`numeroEdicao` INT) RETURNS INT(11)  BEGIN
    DECLARE lucroTotal INT;
    DECLARE custoTotal INT;

    CREATE TEMPORARY TABLE IF NOT EXISTS Temp_TicketInfo (
        num_serie INT,
        Nome VARCHAR(60),
        preco INT,
        Edicao_numero INT
    );


    INSERT INTO Temp_TicketInfo (num_serie, Nome, preco, Edicao_numero)
    SELECT DISTINCT Bilhete.num_serie, Tipo_de_bilhete.Nome, Tipo_de_bilhete.preco, Dia_festival.Edicao_numero
    FROM Bilhete
    JOIN Acesso ON Acesso.Tipo_de_bilhete_Nome_ = Bilhete.Tipo_de_bilhete_Nome AND Bilhete.devolvido <> 1
    JOIN Dia_festival ON Dia_festival.data = Acesso.Dia_festival_data_
    JOIN Tipo_de_bilhete ON Tipo_de_bilhete.Nome = Bilhete.Tipo_de_bilhete_Nome
    WHERE Dia_festival.Edicao_numero = numeroEdicao;

    SELECT SUM(preco) INTO lucroTotal
    FROM Temp_TicketInfo
    WHERE Edicao_numero = numeroEdicao;
    
    SELECT SUM(cachet) INTO custoTotal
    FROM Contrata
    WHERE Contrata.Edicao_numero_ = numeroEdicao;

    DROP TEMPORARY TABLE IF EXISTS Temp_TicketInfo;

    RETURN lucroTotal - custoTotal;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `novoId` () RETURNS INT(11)  BEGIN 

return(	SELECT MAX(numero)
    FROM Edicao) + 1;

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `participantesUltimaEdicao` () RETURNS INT(11)  BEGIN
    BEGIN
    DECLARE ultimaEdicaoId INT;
    DECLARE edicaoParticipantes INT;
    
        SELECT MAX(numero) INTO ultimaEdicaoId
        FROM edicao;

        SELECT COUNT(DISTINCT Participante_codigo_) INTO edicaoParticipantes
  	FROM contrata
        WHERE Contrata.Edicao_numero_ = ultimaEdicaoId;
  

    RETURN edicaoParticipantes;
    END;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `Qtd_espetadores_no_dia` (`dataFestival` DATE) RETURNS INT(11)  BEGIN 

DECLARE espetadores INT;

SELECT Dia_festival.qtd_espetadores into espetadores
FROM Dia_festival 
WHERE Dia_festival.data = dataFestival;

RETURN espetadores;

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `acesso`
--

CREATE TABLE `acesso` (
  `Dia_festival_data_` date NOT NULL,
  `Tipo_de_bilhete_Nome_` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `acesso`
--

INSERT INTO `acesso` (`Dia_festival_data_`, `Tipo_de_bilhete_Nome_`) VALUES
('2023-12-01', 'NosAlive 23 Dia 1'),
('2023-12-01', 'NosAlive 23 Dia 1 e 2'),
('2023-12-02', 'NosAlive 23 Dia 1 e 2'),
('2023-12-02', 'NosAlive23 Dia 2'),
('2023-12-03', 'NosAlive 23 Dia 3');

-- --------------------------------------------------------

--
-- Table structure for table `Bilhete`
--

CREATE TABLE `Bilhete` (
  `num_serie` int(11) NOT NULL,
  `Tipo_de_bilhete_Nome` varchar(30) NOT NULL,
  `Espetador_com_bilhete_Espetador_identificador` int(11) DEFAULT NULL,
  `designacao` varchar(60) DEFAULT NULL,
  `devolvido` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Bilhete`
--

INSERT INTO `Bilhete` (`num_serie`, `Tipo_de_bilhete_Nome`, `Espetador_com_bilhete_Espetador_identificador`, `designacao`, `devolvido`) VALUES
(0, 'NosAlive 23 Dia 1 e 2', 1, NULL, 0),
(1, 'NosAlive 23 Dia 1', 1, NULL, 0),
(2, 'NosAlive23 Dia 2', 1, NULL, 0),
(3, 'NosAlive 23 Dia 1 e 2', 1, NULL, 0),
(4, 'NosAlive 23 Dia 1', 2, NULL, 0),
(5, 'NosAlive 23 Dia 3', 1, NULL, 0),
(6, 'NosAlive 23 Dia 1 e 2', 1, NULL, 0);

--
-- Triggers `Bilhete`
--
DELIMITER $$
CREATE TRIGGER `adicionaEspectadores` AFTER INSERT ON `Bilhete` FOR EACH ROW BEGIN
  
  IF NEW.Espetador_com_bilhete_Espetador_identificador IS NOT NULL AND NEW.devolvido = 0 THEN

    UPDATE Dia_festival
    SET qtd_espetadores = qtd_espetadores + 1
    WHERE (SELECT COUNT(*) FROM acesso a WHERE a.Tipo_de_bilhete_Nome_ = NEW.Tipo_de_bilhete_Nome AND Dia_festival.data = a.Dia_festival_data_) <> 0;

  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `aposEliminarBilhete` AFTER DELETE ON `Bilhete` FOR EACH ROW BEGIN
  
    UPDATE Dia_festival
    SET qtd_espetadores = qtd_espetadores - 1
    WHERE (SELECT COUNT(*) FROM acesso a WHERE a.Tipo_de_bilhete_Nome_ = old.Tipo_de_bilhete_Nome AND Dia_festival.data = a.Dia_festival_data_) <> 0;

END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `decrementaEspetadores` AFTER UPDATE ON `Bilhete` FOR EACH ROW BEGIN
  
  IF NEW.Espetador_com_bilhete_Espetador_identificador IS NULL AND NEW.devolvido = 1 THEN

    UPDATE Dia_festival
    SET qtd_espetadores = qtd_espetadores - 1
    WHERE (SELECT COUNT(*) FROM acesso a WHERE a.Tipo_de_bilhete_Nome_ = NEW.Tipo_de_bilhete_Nome AND Dia_festival.data = a.Dia_festival_data_) <> 0;

  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `lotacaoMaximaAtingida` BEFORE INSERT ON `Bilhete` FOR EACH ROW BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE lotacaoEvento INT;
    DECLARE lotacaoAtual INT;

    DECLARE cursor_lotacaoEvento CURSOR FOR
        SELECT DISTINCT e.lotacao
        FROM Edicao e
        JOIN Dia_festival df ON e.numero = df.Edicao_numero
        JOIN acesso a ON df.data = a.Dia_festival_data_
        WHERE a.Tipo_de_bilhete_Nome_ = NEW.Tipo_de_bilhete_Nome;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cursor_lotacaoEvento;

    read_loop: LOOP
        FETCH cursor_lotacaoEvento INTO lotacaoEvento;

        IF done THEN
            LEAVE read_loop;
        END IF;

        SELECT COUNT(*) INTO lotacaoAtual
        FROM Dia_festival df
        WHERE df.Edicao_numero IN (
            SELECT df_inner.Edicao_numero
            FROM Dia_festival df_inner
            JOIN acesso a ON df_inner.data = a.Dia_festival_data_
            WHERE a.Tipo_de_bilhete_Nome_ = NEW.Tipo_de_bilhete_Nome
            AND df_inner.data = df.data
        )
        AND qtd_espetadores >= lotacaoEvento;

        IF lotacaoAtual > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lotação máxima atingida';
        END IF;
    END LOOP;

    CLOSE cursor_lotacaoEvento;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `Contrata`
--

CREATE TABLE `Contrata` (
  `Edicao_numero_` tinyint(4) NOT NULL,
  `Participante_codigo_` smallint(6) NOT NULL,
  `cachet` int(11) DEFAULT NULL,
  `Palco_Edicao_numero` tinyint(4) NOT NULL,
  `Palco_codigo` tinyint(4) NOT NULL,
  `Dia_festival_data` date NOT NULL,
  `hora_inicio` time DEFAULT NULL,
  `hora_fim` time DEFAULT NULL,
  `Convidado_Edicao_numero_` tinyint(4) NOT NULL,
  `Convidado_Participante_codigo_` smallint(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Contrata`
--

INSERT INTO `Contrata` (`Edicao_numero_`, `Participante_codigo_`, `cachet`, `Palco_Edicao_numero`, `Palco_codigo`, `Dia_festival_data`, `hora_inicio`, `hora_fim`, `Convidado_Edicao_numero_`, `Convidado_Participante_codigo_`) VALUES
(1, 1, 100, 1, 1, '2023-12-01', '17:00:00', '18:00:00', 1, 1),
(1, 12, 150, 1, 2, '2023-12-02', '17:00:00', '18:00:00', 1, 1);

-- --------------------------------------------------------

--
-- Table structure for table `Dia_festival`
--

CREATE TABLE `Dia_festival` (
  `Edicao_numero` tinyint(4) NOT NULL,
  `data` date NOT NULL,
  `qtd_espetadores` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Dia_festival`
--

INSERT INTO `Dia_festival` (`Edicao_numero`, `data`, `qtd_espetadores`) VALUES
(1, '2023-12-01', 5),
(1, '2023-12-02', 4),
(1, '2023-12-03', 1),
(2, '2024-12-01', 4),
(2, '2024-12-02', 3),
(2, '2024-12-03', 1),
(3, '2025-12-30', 5),
(3, '2025-12-31', 4),
(3, '2026-01-01', 1);

-- --------------------------------------------------------

--
-- Table structure for table `Edicao`
--

CREATE TABLE `Edicao` (
  `numero` tinyint(4) NOT NULL,
  `nome` varchar(60) DEFAULT NULL,
  `localidade` varchar(60) DEFAULT NULL,
  `local` varchar(60) DEFAULT NULL,
  `data_inicio` date DEFAULT NULL,
  `data_fim` date DEFAULT NULL,
  `lotacao` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Edicao`
--

INSERT INTO `Edicao` (`numero`, `nome`, `localidade`, `local`, `data_inicio`, `data_fim`, `lotacao`) VALUES
(1, 'Nos Alive', 'Lisboa', 'Saldanha', '2023-12-01', '2023-12-03', 10),
(2, 'Nos Alive', 'Lisboa', 'Saldanha', '2024-12-01', '2024-12-03', 10),
(3, 'Nos Alive', 'Lisboa', 'Saldanha', '2025-12-30', '2026-01-01', 10);

-- --------------------------------------------------------

--
-- Stand-in structure for view `edicao_dia_espetadores`
-- (See below for the actual view)
--
CREATE TABLE `edicao_dia_espetadores` (
`Edicao` tinyint(4)
,`Dia` date
,`Espetadores` int(11)
);

-- --------------------------------------------------------

--
-- Table structure for table `Elemento_grupo`
--

CREATE TABLE `Elemento_grupo` (
  `Individual_Participante_codigo_` smallint(6) NOT NULL,
  `Grupo_Participante_codigo_` smallint(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `Entrevista`
--

CREATE TABLE `Entrevista` (
  `Participante_codigo_` smallint(6) NOT NULL,
  `Jornalista_num_carteira_profissional_` int(11) NOT NULL,
  `data` date DEFAULT NULL,
  `hora` time DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Entrevista`
--

INSERT INTO `Entrevista` (`Participante_codigo_`, `Jornalista_num_carteira_profissional_`, `data`, `hora`) VALUES
(1, 0, '2023-12-01', '17:00:00'),
(2, 0, NULL, NULL),
(3, 0, NULL, NULL),
(4, 0, NULL, NULL),
(4, 1, NULL, NULL),
(10, 0, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `Espetador_com_bilhete`
--

CREATE TABLE `Espetador_com_bilhete` (
  `identificador` int(11) NOT NULL,
  `idade` tinyint(4) DEFAULT NULL,
  `profissao` varchar(60) DEFAULT NULL,
  `tipo` enum('P','C') NOT NULL,
  `nome` varchar(100) DEFAULT NULL,
  `genero` enum('M','F') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Espetador_com_bilhete`
--

INSERT INTO `Espetador_com_bilhete` (`identificador`, `idade`, `profissao`, `tipo`, `nome`, `genero`) VALUES
(1, 15, NULL, 'P', 'Joao pagante', 'M'),
(2, NULL, 'Arquiteto', 'C', 'Joao Convidado', 'M');

--
-- Triggers `Espetador_com_bilhete`
--
DELIMITER $$
CREATE TRIGGER `tipoEspectadorComBilhete` BEFORE INSERT ON `Espetador_com_bilhete` FOR EACH ROW BEGIN 
    IF (NEW.tipo = 'P' AND NEW.idade IS NULL) THEN 
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Se o espectador for pagante então a idade deve ser dada e a profissão não';
    ELSEIF (NEW.tipo = 'C' AND NEW.profissao IS NULL) THEN 
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Se o espectador for convidado então a idade não deve ser dada e a profissão deve';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `Estilo`
--

CREATE TABLE `Estilo` (
  `Nome` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Estilo`
--

INSERT INTO `Estilo` (`Nome`) VALUES
('Blues'),
('Eletrônico'),
('Hip-hop'),
('Jazz'),
('Pimba'),
('Pop'),
('R&B'),
('Rock');

-- --------------------------------------------------------

--
-- Stand-in structure for view `estilos_musicais_por_edicao`
-- (See below for the actual view)
--
CREATE TABLE `estilos_musicais_por_edicao` (
`Edicao` tinyint(4)
,`Estilo` varchar(30)
,`Qtd_artistas` bigint(21)
);

-- --------------------------------------------------------

--
-- Table structure for table `estilo_de_artista`
--

CREATE TABLE `estilo_de_artista` (
  `Participante_codigo_` smallint(6) NOT NULL,
  `Estilo_Nome_` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `estilo_de_artista`
--

INSERT INTO `estilo_de_artista` (`Participante_codigo_`, `Estilo_Nome_`) VALUES
(1, 'Blues'),
(1, 'Pop'),
(2, 'Pop'),
(3, 'Pop'),
(4, 'Pimba'),
(5, 'Hip-hop'),
(5, 'Rock'),
(6, 'Hip-hop'),
(7, 'Jazz'),
(8, 'Eletrônico'),
(8, 'Pop'),
(8, 'R&B'),
(9, 'Pimba'),
(9, 'Pop');

-- --------------------------------------------------------

--
-- Table structure for table `Grupo`
--

CREATE TABLE `Grupo` (
  `Participante_codigo` smallint(6) NOT NULL,
  `qtd_elementos` tinyint(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `Individual`
--

CREATE TABLE `Individual` (
  `Participante_codigo` smallint(6) NOT NULL,
  `Pais_nome` varchar(60) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `Jornalista`
--

CREATE TABLE `Jornalista` (
  `Media_nome` varchar(30) NOT NULL,
  `num_carteira_profissional` int(11) NOT NULL,
  `nome` varchar(100) DEFAULT NULL,
  `genero` enum('M','F') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Jornalista`
--

INSERT INTO `Jornalista` (`Media_nome`, `num_carteira_profissional`, `nome`, `genero`) VALUES
('SIC', 0, 'Clara de Sousa', 'F'),
('SIC', 1, 'José Rodrigues dos Santos', 'M');

-- --------------------------------------------------------

--
-- Table structure for table `Livre_transito`
--

CREATE TABLE `Livre_transito` (
  `Edicao_numero_` tinyint(4) NOT NULL,
  `Jornalista_num_carteira_profissional_` int(11) NOT NULL,
  `numero` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `Media`
--

CREATE TABLE `Media` (
  `nome` varchar(30) NOT NULL,
  `tipo` enum('Rádio','TV','Jornal','Revista') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Media`
--

INSERT INTO `Media` (`nome`, `tipo`) VALUES
('SIC', 'TV');

-- --------------------------------------------------------

--
-- Table structure for table `montado`
--

CREATE TABLE `montado` (
  `Palco_Edicao_numero_` tinyint(4) NOT NULL,
  `Palco_codigo_` tinyint(4) NOT NULL,
  `Tecnico_numero_` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `montado`
--

INSERT INTO `montado` (`Palco_Edicao_numero_`, `Palco_codigo_`, `Tecnico_numero_`) VALUES
(1, 1, 1);

--
-- Triggers `montado`
--
DELIMITER $$
CREATE TRIGGER `montaPalcoDoArtista` BEFORE INSERT ON `montado` FOR EACH ROW BEGIN
    DECLARE isRoadie BOOLEAN;
    DECLARE participanteTecnico INT;
    DECLARE palcoParticipante INT;

    SELECT roadie INTO isRoadie
    FROM Tecnico
    WHERE Tecnico.numero = NEW.Tecnico_numero_ AND Tecnico.roadie = TRUE;

    SELECT Participante_codigo INTO participanteTecnico
    FROM Tecnico
    WHERE Tecnico.numero = NEW.Tecnico_numero_;
    
    SELECT Palco_codigo INTO palcoParticipante
    FROM Contrata
    WHERE (Contrata.Participante_codigo_ = participanteTecnico 
    AND Contrata.Palco_Edicao_numero = NEW.Palco_Edicao_numero_); 


    IF isRoadie AND new.Palco_codigo_ <> palcoParticipante THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Este técnico não pode montar um palco que o seu participante não atua na respetiva edição';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `Pais`
--

CREATE TABLE `Pais` (
  `nome` varchar(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `Palco`
--

CREATE TABLE `Palco` (
  `Edicao_numero` tinyint(4) NOT NULL,
  `codigo` tinyint(4) NOT NULL,
  `nome` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Palco`
--

INSERT INTO `Palco` (`Edicao_numero`, `codigo`, `nome`) VALUES
(1, 1, 'Palco principal'),
(1, 2, 'Palco Secundario'),
(2, 1, 'Palco principal'),
(2, 2, 'Palco Secundario'),
(3, 1, 'Palco principal'),
(3, 2, 'Palco Secundario');

-- --------------------------------------------------------

--
-- Table structure for table `Papel`
--

CREATE TABLE `Papel` (
  `Nome` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `papel_no_grupo`
--

CREATE TABLE `papel_no_grupo` (
  `Elemento_grupo_Individual_Participante_codigo__` smallint(6) NOT NULL,
  `Elemento_grupo_Grupo_Participante_codigo__` smallint(6) NOT NULL,
  `Papel_Nome_` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `Participante`
--

CREATE TABLE `Participante` (
  `codigo` smallint(6) NOT NULL,
  `nome` varchar(80) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Participante`
--

INSERT INTO `Participante` (`codigo`, `nome`) VALUES
(1, 'John Mayer'),
(2, 'Alicia Keys'),
(3, 'David Carreira'),
(4, 'Quim Barreiros'),
(5, 'John Legend'),
(6, 'Taylor Swift'),
(7, 'Ed Sheeran'),
(8, 'Adele'),
(9, 'Beyoncé'),
(10, 'Justin Bieber'),
(11, 'Lady Gaga'),
(12, 'Drake'),
(13, 'Katy Perry'),
(14, 'Bruno Mars');

-- --------------------------------------------------------

--
-- Table structure for table `Reportagem`
--

CREATE TABLE `Reportagem` (
  `Dia_festival_data_` date NOT NULL,
  `Jornalista_num_carteira_profissional_` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Stand-in structure for view `resultados_diarios`
-- (See below for the actual view)
--
CREATE TABLE `resultados_diarios` (
`Dia` date
,`Espectadores` bigint(21)
,`Tipo_bilhete` varchar(30)
,`lucroDiarioBilhete` bigint(26)
);

-- --------------------------------------------------------

--
-- Table structure for table `Tecnico`
--

CREATE TABLE `Tecnico` (
  `numero` int(11) NOT NULL,
  `nome` varchar(120) DEFAULT NULL,
  `roadie` tinyint(1) NOT NULL,
  `Participante_codigo` smallint(6) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Tecnico`
--

INSERT INTO `Tecnico` (`numero`, `nome`, `roadie`, `Participante_codigo`) VALUES
(1, 'Pedro John Mayer 1', 1, 1),
(2, 'Joao Alicia Keys', 1, 2);

--
-- Triggers `Tecnico`
--
DELIMITER $$
CREATE TRIGGER `casoSejaRoadie` BEFORE INSERT ON `Tecnico` FOR EACH ROW BEGIN 
	IF(NEW.roadie = FALSE AND NEW.Participante_codigo IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Não pode seguir um participante se não for roadie';
    ELSEIF (NEW.roadie = TRUE AND NEW.Participante_codigo IS NULL) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Se roadie for verdadeiro, Participante_codigo deve ser preenchido.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `Tema`
--

CREATE TABLE `Tema` (
  `Edicao_numero` tinyint(4) NOT NULL,
  `Participante_codigo` smallint(6) NOT NULL,
  `nr_ordem` tinyint(4) NOT NULL,
  `titulo` varchar(60) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- --------------------------------------------------------

--
-- Table structure for table `Tipo_de_bilhete`
--

CREATE TABLE `Tipo_de_bilhete` (
  `Nome` varchar(30) NOT NULL,
  `preco` decimal(6,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

--
-- Dumping data for table `Tipo_de_bilhete`
--

INSERT INTO `Tipo_de_bilhete` (`Nome`, `preco`) VALUES
('NosAlive 23 Dia 1', 60.00),
('NosAlive 23 Dia 1 e 2', 100.00),
('NosAlive 23 Dia 3', 60.00),
('NosAlive23 Dia 2', 60.00);

-- --------------------------------------------------------

--
-- Stand-in structure for view `todos_os_participantes`
-- (See below for the actual view)
--
CREATE TABLE `todos_os_participantes` (
`nome` varchar(80)
,`Ultima_Atuacao` int(8)
,`cachet` int(11)
);

-- --------------------------------------------------------

--
-- Structure for view `edicao_dia_espetadores`
--
DROP TABLE IF EXISTS `edicao_dia_espetadores`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `edicao_dia_espetadores`  AS SELECT `dia_festival`.`Edicao_numero` AS `Edicao`, `dia_festival`.`data` AS `Dia`, `dia_festival`.`qtd_espetadores` AS `Espetadores` FROM (`dia_festival` join `edicao` on(`dia_festival`.`Edicao_numero` = `edicao`.`numero`)) ;

-- --------------------------------------------------------

--
-- Structure for view `estilos_musicais_por_edicao`
--
DROP TABLE IF EXISTS `estilos_musicais_por_edicao`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `estilos_musicais_por_edicao`  AS SELECT `e`.`numero` AS `Edicao`, `estilo_de_artista`.`Estilo_Nome_` AS `Estilo`, count(`participante`.`codigo`) AS `Qtd_artistas` FROM (((`edicao` `e` join `contrata` on(`contrata`.`Edicao_numero_` = `e`.`numero`)) join `participante` on(`participante`.`codigo` = `contrata`.`Participante_codigo_`)) join `estilo_de_artista` on(`estilo_de_artista`.`Participante_codigo_` = `participante`.`codigo`)) GROUP BY `e`.`numero`, `estilo_de_artista`.`Estilo_Nome_` ORDER BY `e`.`numero` ASC ;

-- --------------------------------------------------------

--
-- Structure for view `resultados_diarios`
--
DROP TABLE IF EXISTS `resultados_diarios`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `resultados_diarios`  AS SELECT `a`.`Dia_festival_data_` AS `Dia`, count(`a`.`Dia_festival_data_`) AS `Espectadores`, `t`.`Nome` AS `Tipo_bilhete`, floor(`t`.`preco` / (select count(0) from `acesso` `a1` where `a1`.`Tipo_de_bilhete_Nome_` = `t`.`Nome`)) * count(`a`.`Dia_festival_data_`) AS `lucroDiarioBilhete` FROM (((`dia_festival` `df` join `acesso` `a` on(`df`.`data` = `a`.`Dia_festival_data_`)) join `bilhete` `b` on(`a`.`Tipo_de_bilhete_Nome_` = `b`.`Tipo_de_bilhete_Nome` and `b`.`devolvido` = 0)) join `tipo_de_bilhete` `t` on(`b`.`Tipo_de_bilhete_Nome` = `t`.`Nome`)) GROUP BY `df`.`data`, `t`.`Nome` ;

-- --------------------------------------------------------

--
-- Structure for view `todos_os_participantes`
--
DROP TABLE IF EXISTS `todos_os_participantes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `todos_os_participantes`  AS SELECT `rankedcontrata`.`nome` AS `nome`, floor(abs((to_days(`rankedcontrata`.`data_inicio`) - to_days(current_timestamp())) / 365)) AS `Ultima_Atuacao`, `rankedcontrata`.`cachet` AS `cachet` FROM (select `participante`.`nome` AS `nome`,`edicao`.`data_inicio` AS `data_inicio`,`contrata`.`cachet` AS `cachet`,row_number() over ( partition by `participante`.`codigo` order by `edicao`.`data_inicio` desc) AS `RowNum` from ((`participante` join `contrata` on(`participante`.`codigo` = `contrata`.`Participante_codigo_`)) join `edicao` on(`contrata`.`Edicao_numero_` = `edicao`.`numero`)) where `edicao`.`data_inicio` < curdate()) AS `RankedContrata` WHERE `rankedcontrata`.`RowNum` = 1 ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `acesso`
--
ALTER TABLE `acesso`
  ADD PRIMARY KEY (`Dia_festival_data_`,`Tipo_de_bilhete_Nome_`),
  ADD KEY `FK_Tipo_de_bilhete_acesso_Dia_festival_` (`Tipo_de_bilhete_Nome_`);

--
-- Indexes for table `Bilhete`
--
ALTER TABLE `Bilhete`
  ADD PRIMARY KEY (`num_serie`),
  ADD KEY `FK_Bilhete_noname_Tipo_de_bilhete` (`Tipo_de_bilhete_Nome`),
  ADD KEY `FK_Bilhete_tem_Espetador_com_bilhete` (`Espetador_com_bilhete_Espetador_identificador`);

--
-- Indexes for table `Contrata`
--
ALTER TABLE `Contrata`
  ADD PRIMARY KEY (`Edicao_numero_`,`Participante_codigo_`),
  ADD KEY `FK_Participante_Contrata_Edicao_` (`Participante_codigo_`),
  ADD KEY `FK_Contrata_apresenta_Palco` (`Palco_Edicao_numero`,`Palco_codigo`),
  ADD KEY `FK_Contrata_Atuacao_Dia_festival` (`Dia_festival_data`),
  ADD KEY `FK_Participante_Convida_Participante_` (`Convidado_Edicao_numero_`,`Convidado_Participante_codigo_`);

--
-- Indexes for table `Dia_festival`
--
ALTER TABLE `Dia_festival`
  ADD PRIMARY KEY (`data`),
  ADD KEY `FK_Dia_festival_noname_Edicao` (`Edicao_numero`);

--
-- Indexes for table `Edicao`
--
ALTER TABLE `Edicao`
  ADD PRIMARY KEY (`numero`);

--
-- Indexes for table `Elemento_grupo`
--
ALTER TABLE `Elemento_grupo`
  ADD PRIMARY KEY (`Individual_Participante_codigo_`,`Grupo_Participante_codigo_`),
  ADD KEY `FK_Grupo_Elemento_grupo_Individual_` (`Grupo_Participante_codigo_`);

--
-- Indexes for table `Entrevista`
--
ALTER TABLE `Entrevista`
  ADD PRIMARY KEY (`Participante_codigo_`,`Jornalista_num_carteira_profissional_`),
  ADD KEY `FK_Jornalista_Entrevista_Participante_` (`Jornalista_num_carteira_profissional_`);

--
-- Indexes for table `Espetador_com_bilhete`
--
ALTER TABLE `Espetador_com_bilhete`
  ADD PRIMARY KEY (`identificador`);

--
-- Indexes for table `Estilo`
--
ALTER TABLE `Estilo`
  ADD PRIMARY KEY (`Nome`);

--
-- Indexes for table `estilo_de_artista`
--
ALTER TABLE `estilo_de_artista`
  ADD PRIMARY KEY (`Participante_codigo_`,`Estilo_Nome_`),
  ADD KEY `FK_Estilo_estilo_de_artista_Participante_` (`Estilo_Nome_`);

--
-- Indexes for table `Grupo`
--
ALTER TABLE `Grupo`
  ADD PRIMARY KEY (`Participante_codigo`);

--
-- Indexes for table `Individual`
--
ALTER TABLE `Individual`
  ADD PRIMARY KEY (`Participante_codigo`),
  ADD KEY `FK_Individual_origem_Pais` (`Pais_nome`);

--
-- Indexes for table `Jornalista`
--
ALTER TABLE `Jornalista`
  ADD PRIMARY KEY (`num_carteira_profissional`),
  ADD KEY `FK_Jornalista_representa_Media` (`Media_nome`);

--
-- Indexes for table `Livre_transito`
--
ALTER TABLE `Livre_transito`
  ADD PRIMARY KEY (`Edicao_numero_`,`Jornalista_num_carteira_profissional_`),
  ADD KEY `FK_Jornalista_Livre_transito_Edicao_` (`Jornalista_num_carteira_profissional_`);

--
-- Indexes for table `Media`
--
ALTER TABLE `Media`
  ADD PRIMARY KEY (`nome`);

--
-- Indexes for table `montado`
--
ALTER TABLE `montado`
  ADD PRIMARY KEY (`Palco_Edicao_numero_`,`Palco_codigo_`,`Tecnico_numero_`),
  ADD KEY `FK_Tecnico_montado_Palco_` (`Tecnico_numero_`);

--
-- Indexes for table `Pais`
--
ALTER TABLE `Pais`
  ADD PRIMARY KEY (`nome`);

--
-- Indexes for table `Palco`
--
ALTER TABLE `Palco`
  ADD PRIMARY KEY (`Edicao_numero`,`codigo`);

--
-- Indexes for table `Papel`
--
ALTER TABLE `Papel`
  ADD PRIMARY KEY (`Nome`);

--
-- Indexes for table `papel_no_grupo`
--
ALTER TABLE `papel_no_grupo`
  ADD PRIMARY KEY (`Elemento_grupo_Individual_Participante_codigo__`,`Elemento_grupo_Grupo_Participante_codigo__`,`Papel_Nome_`),
  ADD KEY `FK_Papel_papel_no_grupo_Elemento_grupo_` (`Papel_Nome_`);

--
-- Indexes for table `Participante`
--
ALTER TABLE `Participante`
  ADD PRIMARY KEY (`codigo`);

--
-- Indexes for table `Reportagem`
--
ALTER TABLE `Reportagem`
  ADD PRIMARY KEY (`Dia_festival_data_`,`Jornalista_num_carteira_profissional_`),
  ADD KEY `FK_Jornalista_Reportagem_Dia_festival_` (`Jornalista_num_carteira_profissional_`);

--
-- Indexes for table `Tecnico`
--
ALTER TABLE `Tecnico`
  ADD PRIMARY KEY (`numero`),
  ADD KEY `FK_Roadie_Participante` (`Participante_codigo`);

--
-- Indexes for table `Tema`
--
ALTER TABLE `Tema`
  ADD PRIMARY KEY (`Edicao_numero`,`Participante_codigo`,`nr_ordem`);

--
-- Indexes for table `Tipo_de_bilhete`
--
ALTER TABLE `Tipo_de_bilhete`
  ADD PRIMARY KEY (`Nome`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `acesso`
--
ALTER TABLE `acesso`
  ADD CONSTRAINT `FK_Dia_festival_acesso_Tipo_de_bilhete_` FOREIGN KEY (`Dia_festival_data_`) REFERENCES `Dia_festival` (`data`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Tipo_de_bilhete_acesso_Dia_festival_` FOREIGN KEY (`Tipo_de_bilhete_Nome_`) REFERENCES `Tipo_de_bilhete` (`Nome`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Bilhete`
--
ALTER TABLE `Bilhete`
  ADD CONSTRAINT `FK_Bilhete_noname_Tipo_de_bilhete` FOREIGN KEY (`Tipo_de_bilhete_Nome`) REFERENCES `Tipo_de_bilhete` (`Nome`) ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Bilhete_tem_Espetador_com_bilhete` FOREIGN KEY (`Espetador_com_bilhete_Espetador_identificador`) REFERENCES `Espetador_com_bilhete` (`identificador`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `Contrata`
--
ALTER TABLE `Contrata`
  ADD CONSTRAINT `FK_Contrata_Atuacao_Dia_festival` FOREIGN KEY (`Dia_festival_data`) REFERENCES `Dia_festival` (`data`) ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Contrata_apresenta_Palco` FOREIGN KEY (`Palco_Edicao_numero`,`Palco_codigo`) REFERENCES `Palco` (`Edicao_numero`, `codigo`) ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Edicao_Contrata_Participante_` FOREIGN KEY (`Edicao_numero_`) REFERENCES `Edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_Contrata_Edicao_` FOREIGN KEY (`Participante_codigo_`) REFERENCES `Participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_Convida_Participante_` FOREIGN KEY (`Convidado_Edicao_numero_`,`Convidado_Participante_codigo_`) REFERENCES `Contrata` (`Edicao_numero_`, `Participante_codigo_`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Dia_festival`
--
ALTER TABLE `Dia_festival`
  ADD CONSTRAINT `FK_Dia_festival_noname_Edicao` FOREIGN KEY (`Edicao_numero`) REFERENCES `Edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Elemento_grupo`
--
ALTER TABLE `Elemento_grupo`
  ADD CONSTRAINT `FK_Grupo_Elemento_grupo_Individual_` FOREIGN KEY (`Grupo_Participante_codigo_`) REFERENCES `Grupo` (`Participante_codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Individual_Elemento_grupo_Grupo_` FOREIGN KEY (`Individual_Participante_codigo_`) REFERENCES `Individual` (`Participante_codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Entrevista`
--
ALTER TABLE `Entrevista`
  ADD CONSTRAINT `FK_Jornalista_Entrevista_Participante_` FOREIGN KEY (`Jornalista_num_carteira_profissional_`) REFERENCES `Jornalista` (`num_carteira_profissional`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_Entrevista_Jornalista_` FOREIGN KEY (`Participante_codigo_`) REFERENCES `Participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `estilo_de_artista`
--
ALTER TABLE `estilo_de_artista`
  ADD CONSTRAINT `FK_Estilo_estilo_de_artista_Participante_` FOREIGN KEY (`Estilo_Nome_`) REFERENCES `Estilo` (`Nome`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_estilo_de_artista_Estilo_` FOREIGN KEY (`Participante_codigo_`) REFERENCES `Participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Grupo`
--
ALTER TABLE `Grupo`
  ADD CONSTRAINT `FK_Grupo_Participante` FOREIGN KEY (`Participante_codigo`) REFERENCES `Participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Individual`
--
ALTER TABLE `Individual`
  ADD CONSTRAINT `FK_Individual_Participante` FOREIGN KEY (`Participante_codigo`) REFERENCES `Participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Individual_origem_Pais` FOREIGN KEY (`Pais_nome`) REFERENCES `Pais` (`nome`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `Jornalista`
--
ALTER TABLE `Jornalista`
  ADD CONSTRAINT `FK_Jornalista_representa_Media` FOREIGN KEY (`Media_nome`) REFERENCES `Media` (`nome`) ON UPDATE CASCADE;

--
-- Constraints for table `Livre_transito`
--
ALTER TABLE `Livre_transito`
  ADD CONSTRAINT `FK_Edicao_Livre_transito_Jornalista_` FOREIGN KEY (`Edicao_numero_`) REFERENCES `Edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Jornalista_Livre_transito_Edicao_` FOREIGN KEY (`Jornalista_num_carteira_profissional_`) REFERENCES `Jornalista` (`num_carteira_profissional`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `montado`
--
ALTER TABLE `montado`
  ADD CONSTRAINT `FK_Palco_montado_Tecnico_` FOREIGN KEY (`Palco_Edicao_numero_`,`Palco_codigo_`) REFERENCES `Palco` (`Edicao_numero`, `codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Tecnico_montado_Palco_` FOREIGN KEY (`Tecnico_numero_`) REFERENCES `Tecnico` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Palco`
--
ALTER TABLE `Palco`
  ADD CONSTRAINT `FK_Palco_tem_Edicao` FOREIGN KEY (`Edicao_numero`) REFERENCES `Edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `papel_no_grupo`
--
ALTER TABLE `papel_no_grupo`
  ADD CONSTRAINT `FK_Elemento_grupo_papel_no_grupo_Papel_` FOREIGN KEY (`Elemento_grupo_Individual_Participante_codigo__`,`Elemento_grupo_Grupo_Participante_codigo__`) REFERENCES `Elemento_grupo` (`Individual_Participante_codigo_`, `Grupo_Participante_codigo_`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Papel_papel_no_grupo_Elemento_grupo_` FOREIGN KEY (`Papel_Nome_`) REFERENCES `Papel` (`Nome`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Reportagem`
--
ALTER TABLE `Reportagem`
  ADD CONSTRAINT `FK_Dia_festival_Reportagem_Jornalista_` FOREIGN KEY (`Dia_festival_data_`) REFERENCES `Dia_festival` (`data`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Jornalista_Reportagem_Dia_festival_` FOREIGN KEY (`Jornalista_num_carteira_profissional_`) REFERENCES `Jornalista` (`num_carteira_profissional`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Tecnico`
--
ALTER TABLE `Tecnico`
  ADD CONSTRAINT `FK_Roadie_Participante` FOREIGN KEY (`Participante_codigo`) REFERENCES `Participante` (`codigo`) ON UPDATE CASCADE;

--
-- Constraints for table `Tema`
--
ALTER TABLE `Tema`
  ADD CONSTRAINT `FK_Tema_enterpretado_Contrata` FOREIGN KEY (`Edicao_numero`,`Participante_codigo`) REFERENCES `Contrata` (`Edicao_numero_`, `Participante_codigo_`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
