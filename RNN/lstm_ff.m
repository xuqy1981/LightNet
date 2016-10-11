function [ net,res,opts ] = lstm_ff( net,inputs,opts )
%NET_FF Summary of this function goes here
%   Detailed explanation goes here

    
    if opts.use_gpu
        inputs.data=gpuArray(single(inputs.data));
        if isfield(inputs,'labels')
            inputs.labels=gpuArray(single(inputs.labels));
        end
        if isfield(inputs,'predicts')
            inputs.predicts=gpuArray(single(inputs.predicts));
           
        end
    end
    
    n_frames=opts.parameters.n_frames;
    
    n_cell_nodes=opts.parameters.n_cell_nodes;
    n_hidden_nodes=opts.parameters.n_hidden_nodes;
    batch_size=opts.parameters.batch_size;
    
    res.Hidden{1}=zeros(n_hidden_nodes,batch_size,'like',inputs.data);
    res.Cell{1}(1).x=zeros(n_cell_nodes,batch_size,'like',inputs.data);
 
    if isfield(inputs,'labels')
        opts.err=zeros(2,n_frames,'like',inputs.data);
        opts.loss=zeros(1,n_frames,'like',inputs.data);
    end
    
   
    if isfield(inputs,'predicts')
        opts.outputs=zeros(size(inputs.predicts),'like',inputs.data);
    end
    for f=1:n_frames
        
        %Process inputs
        res.Gates{f}(1).x=[res.Hidden{f};inputs.data(:,:,f)];%inputs
        res.Input{f}(1).x=res.Gates{f}(1).x;
        
        %Gates
        [ net{1},res.Gates{f},opts ] = net_ff( net{1},res.Gates{f},opts );
        
        %Input transform
        [ net{2},res.Input{f},opts ] = net_ff( net{2},res.Input{f},opts ); 
        
        %Update cells
        res.Cell{f+1}(1).x=res.Gates{f}(end).x(1:n_cell_nodes,:).*res.Input{f}(end).x+res.Gates{f}(end).x(n_cell_nodes+1:2*n_cell_nodes,:).*res.Cell{f}(1).x;

        %Output transform
        [ net{3},res.Cell{f+1},opts ] = net_ff( net{3},res.Cell{f+1},opts ); 
        res.Hidden{f+1}=res.Gates{f}(end).x(2*n_cell_nodes+1:3*n_cell_nodes,:).*res.Cell{f+1}(end).x;
        
        %Data fitting transform
        res.Fit{f}(1).x=res.Hidden{f+1};
        if isfield(inputs,'predicts')
            res.Fit{f}(1).predicts=inputs.predicts(:,:,f);
        elseif isfield(inputs,'labels')
            res.Fit{f}(1).class=inputs.labels(:,f);
        end
        [ net{4},res.Fit{f},opts ] = net_ff( net{4},res.Fit{f},opts ); 
        if isfield(inputs,'labels')
            opts.err(:,f)=error_multiclass(res.Fit{f}(1).class,res.Fit{f});
        end
        opts.loss(:,f)=mean(res.Fit{f}(end).x(:));
        
        opts.outputs(:,:,f)=res.Fit{f}(end-1).x;
        
    end
    if isfield(inputs,'labels')
        opts.err=mean(opts.err,2)./opts.parameters.batch_size;
        
    end
    opts.loss=mean(opts.loss(:));
    
end

