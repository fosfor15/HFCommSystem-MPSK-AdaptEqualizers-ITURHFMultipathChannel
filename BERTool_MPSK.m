function [BER, numBits] = BERTool_MPSK(EbNo, maxNumErrs, maxNumBits)

    persistent FullOperatingTime

    % Display Line on the Start of Imitation Modeling
    disp('======================================');
    % Start time
    tStart = clock;
    % Total duration of Imitation Modeling
    % Saving for each trials. To restart need 'clear all' command.
    if isempty(FullOperatingTime)
        FullOperatingTime = 0;
    end
    
    
    %%%%% Initial Information Source %%%%%
    
    % Symbol Rate
    Rs = 1e3;
    
    % Number of Symbols per Frame
    numSymbols = 1e4;
    
    
    %%%%% M-PSK Modulation %%%%%
    
    % Modulation Order
    M = 2;
    % Number of Bits in Symbol
    k = log2(M);
    
    % M-PSK Modulator Object
    MPSKModulator = comm.PSKModulator( ...
        'ModulationOrder', M, ...
        'BitInput', true, ...
        'PhaseOffset', 0, ...
        'SymbolMapping', 'Gray' ...
    );

    % M-PSK Demodulator Object
    MPSKDemodulator = comm.PSKDemodulator( ...
        'ModulationOrder', MPSKModulator.ModulationOrder, ...
        'BitOutput', MPSKModulator.BitInput, ...
        'PhaseOffset', MPSKModulator.PhaseOffset, ...
        'SymbolMapping', MPSKModulator.SymbolMapping, ...
        'DecisionMethod', 'Hard decision' ...
    );


     %%%%% HF Communication Channel with Multipath and Signal Fading %%%%%
    
    % Rayleigh Channel Object
    RayleighChannel = stdchan( ...
        'iturHFMD', ...
        Rs, ...
        1 ...
    );
    RayleighChannel.PathGainsOutputPort = true;
    % Delay in Channel Object
    chanDelay = info(RayleighChannel).ChannelFilterDelay;

    % AWGN Channel Object
    AWGNChannel = comm.AWGNChannel( ...
        'NoiseMethod', 'Signal to noise ratio (Eb/No)', ...
        'EbNo', EbNo, ...
        'SignalPower', 1, ...
        'BitsPerSymbol', k ...
    );    
    
    
    %%%%% Imitation Modeling %%%%%
    
    % Import Java class for BERTool
    import com.mathworks.toolbox.comm.BERTool;
    
    % BER Calculator Object   
    BERCalculater = comm.ErrorRate;
    % BER Intermediate Variable
    BERIm = zeros(3,1);
    
    
    % Imitation Modeling Loop
    tLoop1 = clock;
    while BERIm(2) < maxNumErrs && BERIm(3) < maxNumBits
        
        % Check of User push Stop
        if BERTool.getSimulationStop
            break;
        end
        
        % >>> Transmitter >>>
        
        % Generation of Data Bits
        DataTx = randi([0 1], k*numSymbols, 1);
        % M-PSK modulation
        SignalTx = MPSKModulator(DataTx);
        
        
        % >>> HF Communication Channel with Multipath and Signal Fading  >>>
        
        % Rayleigh Channel
        [SignalChan1, PathGains] = RayleighChannel(SignalTx);
        % AWGN Channel  
        SignalChan2 = AWGNChannel(SignalChan1);
        
        
        % >>> Receiver >>>
        
        % Least squares solution
        SignalRx = SignalChan2 ./ PathGains(:,1);
        % M-PSK Demodulation
        DataRx = MPSKDemodulator([SignalRx(chanDelay+1:end); zeros(chanDelay,1)]);
        
        % BER Calculation
        BERIm = BERCalculater(DataTx, DataRx);
        
    end
    tLoop2 = clock;    
    
    % BER Results
    BER = BERIm(1);
    numBits = BERIm(3);
    disp(['BER = ', num2str(BERIm(1), '%.5g'), ' at Eb/No = ', num2str(EbNo), ' dB']);
    disp(['Number of bits = ', num2str(BERIm(3))]);
    disp(['Number of errors = ', num2str(BERIm(2))]);
    
    
    % Performance of Imitation Modeling
    Performance = BERIm(3) / etime(tLoop2, tLoop1);
    disp(['Performance = ', num2str(Performance), ' bit/sec']);    
    
    % Duration of this Imitation Modeling
    Duration = etime(clock, tStart);
    disp(['Operating time = ', num2str(Duration), ' sec']);
    
    % Total duration of Imitation Modeling
    FullOperatingTime = FullOperatingTime + Duration;
    assignin('base', 'FullOperatingTime', FullOperatingTime);

end